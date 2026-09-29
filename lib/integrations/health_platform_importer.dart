import 'dart:io';

import 'package:health/health.dart';

import '../models/health_record.dart';
import 'apple_clinical_records_importer.dart';
import 'daily_step_aggregator.dart';
import 'health_data_record_mapper.dart';
import 'health_connect_medical_records_importer.dart';
import 'health_import_windows.dart';
import '../sync/import_progress.dart';

class HealthPlatformImporter {
  HealthPlatformImporter({
    Health? health,
    AppleClinicalRecordsImporter? appleClinicalRecords,
    HealthConnectMedicalRecordsImporter? healthConnectMedicalRecords,
  }) : _health = health ?? Health(),
       _appleClinicalRecords =
           appleClinicalRecords ?? AppleClinicalRecordsImporter(),
       _healthConnectMedicalRecords =
           healthConnectMedicalRecords ?? HealthConnectMedicalRecordsImporter();

  static const _queryBatchYears = 10;
  final Health _health;
  final AppleClinicalRecordsImporter _appleClinicalRecords;
  final HealthConnectMedicalRecordsImporter _healthConnectMedicalRecords;
  final _stepAggregator = DailyStepAggregator();
  static const _recordMapper = HealthDataRecordMapper();

  static const sharedDataTypes = <HealthDataType>[
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.BASAL_ENERGY_BURNED,
    HealthDataType.BLOOD_GLUCOSE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.BODY_FAT_PERCENTAGE,
    HealthDataType.BODY_MASS_INDEX,
    HealthDataType.BODY_TEMPERATURE,
    HealthDataType.FLIGHTS_CLIMBED,
    HealthDataType.HEART_RATE,
    HealthDataType.HEIGHT,
    HealthDataType.LEAN_BODY_MASS,
    HealthDataType.MENSTRUATION_FLOW,
    HealthDataType.NUTRITION,
    HealthDataType.RESPIRATORY_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
    HealthDataType.STEPS,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.WATER,
    HealthDataType.WEIGHT,
    HealthDataType.WORKOUT,
    HealthDataType.WORKOUT_ROUTE,
  ];

  /// Check whether a data type is supported on the current device/platform.
  ///
  /// HealthKit on iOS does not support [HealthDataType.TOTAL_CALORIES_BURNED]
  /// (Apple Health only tracks active and basal energy). Even though the health
  /// package mistakenly lists it in its iOS data types, requesting or querying it
  /// on iOS produces a native PlatformException(INVALID_TYPE).
  bool isDataTypeAvailable(HealthDataType type, {bool? isIos}) {
    final onIos = isIos ?? Platform.isIOS;
    if (onIos && type == HealthDataType.TOTAL_CALORIES_BURNED) {
      return false;
    }
    return _health.isDataTypeAvailable(type);
  }

  Future<List<HealthRecord>> importRecords({
    required DateTime since,
    ImportProgressCallback? onProgress,
  }) async {
    await _health.configure();
    if (Platform.isAndroid && !await _health.isHealthConnectAvailable()) {
      throw StateError(
        'Health Connect is not available on this device. Install or update Health Connect, then try again.',
      );
    }

    final availableTypes = sharedDataTypes
        .where(isDataTypeAvailable)
        .toList();
    final records = <HealthRecord>[];
    var totalSteps = Platform.isIOS || Platform.isAndroid ? 1 : 0;
    var completedSteps = 0;
    void report(String message) {
      onProgress?.call(
        ImportProgress(
          fraction: totalSteps == 0 ? 0 : completedSteps / totalSteps,
          message: message,
        ),
      );
    }

    if (availableTypes.isEmpty &&
        !Platform.isIOS &&
        !Platform.isAndroid) {
      throw StateError(
        'No supported health-data types are available on this device.',
      );
    }

    if (availableTypes.isNotEmpty) {
      final permissions = List<HealthDataAccess>.filled(
        availableTypes.length,
        HealthDataAccess.READ,
      );
      final authorized = await _health.requestAuthorization(
        availableTypes,
        permissions: permissions,
      );
      if (!authorized) {
        throw StateError(
          'Health-data access was not granted. You can review permissions in your device settings.',
        );
      }

      final endTime = DateTime.now();
      if (Platform.isAndroid &&
          since.isBefore(endTime.subtract(const Duration(days: 30))) &&
          await _health.isHealthDataHistoryAvailable() &&
          !await _health.isHealthDataHistoryAuthorized()) {
        await _health.requestHealthDataHistoryAuthorization();
      }

      final detailedTypes = availableTypes
          .where((type) => type != HealthDataType.STEPS)
          .toList();
      final stepTypes = availableTypes
          .where((type) => type == HealthDataType.STEPS)
          .toList();
      final windows = _buildWindows(since, endTime);
      final groupsPerWindow =
          (detailedTypes.isEmpty ? 0 : 1) + (stepTypes.isEmpty ? 0 : 1);
      totalSteps =
          windows.length * groupsPerWindow +
          (Platform.isIOS || Platform.isAndroid ? 1 : 0);

      report('Preparing health data');
      for (var index = 0; index < windows.length; index++) {
        final window = windows[index];
        final windowLabel = 'period ${index + 1} of ${windows.length}';
        if (detailedTypes.isNotEmpty) {
          report('Reading health records · $windowLabel');
          records.addAll(
            await _readDetailedRecords(detailedTypes, window.start, window.end),
          );
          completedSteps++;
          report('Read health records · $windowLabel');
        }
        if (stepTypes.isNotEmpty) {
          report('Reading steps · $windowLabel');
          final points = await _health.getHealthDataFromTypes(
            types: stepTypes,
            startTime: window.start,
            endTime: window.end,
          );
          final source = Platform.isIOS ? 'Apple Health' : 'Health Connect';
          records.addAll(
            _stepAggregator.aggregate(
              points.map(_dailyStepSampleFromPoint),
              source: source,
            ),
          );
          completedSteps++;
          report('Read steps · $windowLabel');
        }
      }
    }

    if (Platform.isIOS) {
      report('Reading Apple Health clinical labs');
      records.addAll(
        await _appleClinicalRecords.importLabRecords(since: since),
      );
      completedSteps++;
      report('Read Apple Health clinical labs');
    }
    if (Platform.isAndroid) {
      report('Reading Health Connect laboratory results');
      records.addAll(
        await _healthConnectMedicalRecords.importLabRecords(
          since: since,
          onStatus: (message) {
            onProgress?.call(
              ImportProgress(
                fraction: totalSteps == 0 ? 0 : completedSteps / totalSteps,
                message: message,
              ),
            );
          },
        ),
      );
      completedSteps++;
      report('Read Health Connect laboratory results');
    }
    onProgress?.call(
      const ImportProgress(fraction: 1, message: 'Preparing records to save'),
    );
    return records..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  List<HealthImportWindow> _buildWindows(DateTime since, DateTime until) {
    return buildHealthImportWindows(
      since: since,
      until: until,
      batchYears: _queryBatchYears,
    );
  }

  Future<List<HealthRecord>> _readDetailedRecords(
    List<HealthDataType> types,
    DateTime startTime,
    DateTime endTime,
  ) async {
    final points = await _health.getHealthDataFromTypes(
      types: types,
      startTime: startTime,
      endTime: endTime,
    );
    final fallbackSource = Platform.isIOS ? 'Apple Health' : 'Health Connect';
    return points
        .map(
          (point) =>
              _recordMapper.mapPoint(point, fallbackSource: fallbackSource),
        )
        .toList();
  }

  DailyStepSample _dailyStepSampleFromPoint(HealthDataPoint point) {
    final value = point.value.toJson()['numericValue'];
    if (value is! num) {
      throw const FormatException(
        'Health Connect returned a step record without a numeric value.',
      );
    }
    return DailyStepSample(recordedAt: point.dateFrom, steps: value);
  }
}
