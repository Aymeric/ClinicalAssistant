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

    final availableTypes = sharedDataTypes.where(isDataTypeAvailable).toList();
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

    if (availableTypes.isEmpty && !Platform.isIOS && !Platform.isAndroid) {
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
      final typesPerWindow = detailedTypes.length + stepTypes.length;
      totalSteps =
          windows.length * typesPerWindow +
          (Platform.isIOS || Platform.isAndroid ? 1 : 0);

      report('Preparing health data');
      for (var index = 0; index < windows.length; index++) {
        final window = windows[index];
        final windowLabel = windows.length > 1
            ? 'period ${index + 1} of ${windows.length}'
            : '';
        final windowSuffix = windowLabel.isNotEmpty ? ' · $windowLabel' : '';

        for (final type in detailedTypes) {
          final typeName = HealthDataRecordMapper.labelFor(type);
          report('Reading $typeName$windowSuffix');
          try {
            final typeRecords = await _readDetailedRecords(
              [type],
              window.start,
              window.end,
            );
            records.addAll(typeRecords);
          } catch (_) {
            // If a specific data type fails, proceed with the others.
          }
          completedSteps++;
          report('Read $typeName (${records.length} records)$windowSuffix');
        }

        for (final type in stepTypes) {
          report('Reading steps$windowSuffix');
          try {
            final points = await _health.getHealthDataFromTypes(
              types: [type],
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
          } catch (_) {}
          completedSteps++;
          report('Read steps (${records.length} records)$windowSuffix');
        }
      }
    }

    if (Platform.isIOS) {
      report('Reading Apple Health clinical labs');
      try {
        records.addAll(await _appleClinicalRecords.importLabRecords());
      } catch (_) {
        // Clinical labs are optional; errors should not prevent basic health sync.
      }
      completedSteps++;
      report('Read Apple Health clinical labs (${records.length} records)');
    }
    if (Platform.isAndroid) {
      report('Reading Health Connect laboratory results');
      records.addAll(
        await _healthConnectMedicalRecords.importLabRecords(
          onStatus: (message) {
            onProgress?.call(
              ImportProgress(
                fraction: totalSteps == 0
                    ? 0
                    : ((completedSteps + 0.5) / totalSteps).clamp(0, 1),
                message: message,
              ),
            );
          },
        ),
      );
      completedSteps++;
      report(
        'Read Health Connect laboratory results (${records.length} records)',
      );
    }
    if (records.length > 500) {
      onProgress?.call(
        ImportProgress(
          fraction: 0.95,
          message: 'Indexing ${records.length} records',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 35));
    }
    records.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    onProgress?.call(
      ImportProgress(fraction: 1, message: 'Read ${records.length} records'),
    );
    return records;
  }

  List<HealthImportWindow> _buildWindows(DateTime since, DateTime until) {
    if (since.year <= 1900) {
      // Modern electronic health platforms (HealthKit, Health Connect) only have
      // sensor data from the modern smartwatch era (~2014/2015 onwards).
      // Consolidate pre-modern history into a single historical window so that
      // empty 20th-century decades do not artificially consume the majority of progress steps.
      const modernEraStartYear = 2015;
      if (until.year > modernEraStartYear) {
        final modernStart = DateTime(modernEraStartYear, 1, 1);
        final modernWindows = buildHealthImportWindows(
          since: modernStart,
          until: until,
          batchYears: _queryBatchYears,
        );
        return [
          HealthImportWindow(
            DateTime(since.year, since.month, since.day),
            modernStart,
          ),
          ...modernWindows,
        ];
      }
    }
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
