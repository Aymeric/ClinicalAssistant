import 'dart:io';

import 'package:health/health.dart';
import 'package:flutter/foundation.dart';

import '../models/health_record.dart';
import 'apple_clinical_records_importer.dart';
import 'daily_calorie_aggregator.dart';
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

  static const _queryBatchYears = 1;
  final Health _health;
  final AppleClinicalRecordsImporter _appleClinicalRecords;
  final HealthConnectMedicalRecordsImporter _healthConnectMedicalRecords;
  final _stepAggregator = DailyStepAggregator();
  final _calorieAggregator = DailyCalorieAggregator();
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
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.DISTANCE_WALKING_RUNNING,
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
    HealthDataType.SLEEP_SESSION,
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

  static bool isCalorieType(HealthDataType type) =>
      type == HealthDataType.ACTIVE_ENERGY_BURNED ||
      type == HealthDataType.BASAL_ENERGY_BURNED ||
      type == HealthDataType.TOTAL_CALORIES_BURNED;

  /// Retrieves an initial or refreshed change token from Android Health Connect
  /// to support fast incremental change syncs. Returns null on non-Android platforms.
  Future<String?> getChangesToken({bool? isAndroid}) async {
    final onAndroid = isAndroid ?? Platform.isAndroid;
    if (!onAndroid) return null;
    try {
      final availableTypes = sharedDataTypes
          .where(isDataTypeAvailable)
          .toList();
      if (availableTypes.isEmpty) return null;
      return await _health.getChangesToken(types: availableTypes);
    } catch (e) {
      debugPrint('HealthPlatformImporter - getChangesToken error: $e');
      return null;
    }
  }

  /// Performs an incremental change sync against Health Connect using [changesToken].
  ///
  /// Returns [HealthChangesResult] with updated records and a new token,
  /// or null if the token has expired or changes could not be fetched.
  Future<HealthChangesResult?> importChanges({
    required String changesToken,
    ImportProgressCallback? onProgress,
    bool? isAndroid,
  }) async {
    final onAndroid = isAndroid ?? Platform.isAndroid;
    if (!onAndroid) return null;
    await _health.configure();
    onProgress?.call(
      const ImportProgress(
        fraction: 0.1,
        message: 'Checking for health data changes...',
      ),
    );

    var currentToken = changesToken;
    final allUpsertedPoints = <HealthDataPoint>[];
    final allDeletedRecordIds = <String>[];
    var hasMore = true;
    var iterations = 0;

    while (hasMore) {
      iterations++;
      HealthChangesResponse? response;
      try {
        response = await _health.getChanges(changesToken: currentToken);
      } catch (e) {
        debugPrint('HealthPlatformImporter - getChanges error: $e');
        return null;
      }
      if (response == null) return null;
      if (response.changesTokenExpired) {
        debugPrint(
          'HealthPlatformImporter - Health Connect changes token expired',
        );
        return null;
      }

      allUpsertedPoints.addAll(response.upsertedDataPoints);
      allDeletedRecordIds.addAll(response.deletedRecordIds);
      currentToken = response.nextChangesToken;
      hasMore = response.hasMore;

      onProgress?.call(
        ImportProgress(
          fraction: (0.1 + (iterations * 0.1)).clamp(0.1, 0.7),
          message:
              'Processing updated records (${allUpsertedPoints.length})...',
        ),
      );
    }

    onProgress?.call(
      const ImportProgress(
        fraction: 0.75,
        message: 'Processing changed health records...',
      ),
    );

    final records = <HealthRecord>[];

    // Process steps
    final stepPoints = allUpsertedPoints
        .where((point) => point.type == HealthDataType.STEPS)
        .toList();
    if (stepPoints.isNotEmpty) {
      final affectedDays = stepPoints
          .map(
            (p) => DateTime(p.dateFrom.year, p.dateFrom.month, p.dateFrom.day),
          )
          .toSet();
      for (final day in affectedDays) {
        final start = DateTime(day.year, day.month, day.day);
        final end = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);
        try {
          final dayPoints = await _health.getHealthDataFromTypes(
            types: [HealthDataType.STEPS],
            startTime: start,
            endTime: end,
          );
          records.addAll(
            _stepAggregator.aggregate(
              dayPoints.map(_dailyStepSampleFromPoint),
              source: 'Health Connect',
            ),
          );
        } catch (_) {
          records.addAll(
            _stepAggregator.aggregate(
              stepPoints
                  .where(
                    (p) =>
                        p.dateFrom.year == day.year &&
                        p.dateFrom.month == day.month &&
                        p.dateFrom.day == day.day,
                  )
                  .map(_dailyStepSampleFromPoint),
              source: 'Health Connect',
            ),
          );
        }
      }
    }

    // Process calories
    final caloriePoints = allUpsertedPoints
        .where((point) => isCalorieType(point.type))
        .toList();
    if (caloriePoints.isNotEmpty) {
      for (final type in [
        HealthDataType.TOTAL_CALORIES_BURNED,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.BASAL_ENERGY_BURNED,
      ]) {
        final typePoints = caloriePoints.where((p) => p.type == type).toList();
        if (typePoints.isEmpty) continue;
        final affectedDays = typePoints
            .map(
              (p) =>
                  DateTime(p.dateFrom.year, p.dateFrom.month, p.dateFrom.day),
            )
            .toSet();
        for (final day in affectedDays) {
          final start = DateTime(day.year, day.month, day.day);
          final end = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);
          try {
            final dayPoints = await _health.getHealthDataFromTypes(
              types: [type],
              startTime: start,
              endTime: end,
            );
            final samples = dayPoints
                .where((p) => p.type == type)
                .map((p) => _dailyCalorieSampleFromPoint(p, type))
                .whereType<DailyCalorieSample>();
            if (samples.isNotEmpty) {
              records.addAll(
                _calorieAggregator.aggregate(
                  samples,
                  type: type,
                  source: 'Health Connect',
                ),
              );
            }
          } catch (_) {
            final samples = typePoints
                .where(
                  (p) =>
                      p.dateFrom.year == day.year &&
                      p.dateFrom.month == day.month &&
                      p.dateFrom.day == day.day,
                )
                .map((p) => _dailyCalorieSampleFromPoint(p, type))
                .whereType<DailyCalorieSample>();
            if (samples.isNotEmpty) {
              records.addAll(
                _calorieAggregator.aggregate(
                  samples,
                  type: type,
                  source: 'Health Connect',
                ),
              );
            }
          }
        }
      }
    }

    // Process other points (discrete vitals, workouts, sleep, downsampled heart rate)
    final otherPoints = allUpsertedPoints
        .where(
          (point) =>
              point.type != HealthDataType.STEPS && !isCalorieType(point.type),
        )
        .toList();
    if (otherPoints.isNotEmpty) {
      final (filtered, _) = _downsampleHeartRateIfNeeded(otherPoints, [
        HealthDataType.HEART_RATE,
      ]);
      records.addAll(
        filtered.map(
          (p) => _recordMapper.mapPoint(p, fallbackSource: 'Health Connect'),
        ),
      );
    }

    // Check for any new medical records (labs) if available
    try {
      records.addAll(await _healthConnectMedicalRecords.importLabRecords());
    } catch (_) {}

    return HealthChangesResult(
      records: records,
      nextChangesToken: currentToken,
      deletedRecordIds: allDeletedRecordIds,
    );
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
    void report(String message, {double stepFraction = 0.0}) {
      final fraction = totalSteps == 0
          ? 0.0
          : ((completedSteps + stepFraction.clamp(0.0, 1.0)) / totalSteps)
                .clamp(0.0, 1.0);
      onProgress?.call(ImportProgress(fraction: fraction, message: message));
    }

    if (availableTypes.isEmpty && !Platform.isIOS && !Platform.isAndroid) {
      throw StateError(
        'No supported health-data types are available on this device.',
      );
    }

    if (availableTypes.isNotEmpty) {
      final authTypes = availableTypes;
      final permissions = List<HealthDataAccess>.filled(
        authTypes.length,
        HealthDataAccess.READ,
      );
      final authorized = await _health.requestAuthorization(
        authTypes,
        permissions: permissions,
      );
      if (!authorized) {
        throw StateError(
          'Health-data access was not granted. You can review permissions in your device settings.',
        );
      }

      final endTime = DateTime.now();
      var effectiveSince = since;
      if (Platform.isAndroid && effectiveSince.isBefore(DateTime(1970, 1, 1))) {
        // Health Connect timestamps cannot predate Instant.EPOCH (1970-01-01T00:00:00Z).
        // Clamping to 1970 avoids IllegalArgumentException on Android.
        effectiveSince = DateTime(1970, 1, 1);
      }

      if (Platform.isAndroid &&
          effectiveSince.isBefore(endTime.subtract(const Duration(days: 30)))) {
        var historyAuthorized = false;
        try {
          if (await _health.isHealthDataHistoryAvailable()) {
            historyAuthorized = await _health.isHealthDataHistoryAuthorized();
            if (!historyAuthorized) {
              final granted = await _health
                  .requestHealthDataHistoryAuthorization();
              historyAuthorized =
                  granted || await _health.isHealthDataHistoryAuthorized();
            }
          }
        } catch (_) {}

        if (!historyAuthorized) {
          final thirtyDaysAgo = endTime.subtract(const Duration(days: 30));
          if (effectiveSince.isBefore(thirtyDaysAgo)) {
            effectiveSince = thirtyDaysAgo;
          }
        }
      }

      final stepTypes = availableTypes
          .where((type) => type == HealthDataType.STEPS)
          .toList();
      final calorieTypes = availableTypes.where(isCalorieType).toList();
      final pagedTypes = availableTypes.where(isPagedDetailedType).toList();
      final discreteTypes = availableTypes
          .where(
            (type) =>
                type != HealthDataType.STEPS &&
                !isCalorieType(type) &&
                !isPagedDetailedType(type),
          )
          .toList();

      final trackerTypes = [...pagedTypes, ...calorieTypes, ...stepTypes];
      final windows = _buildWindows(effectiveSince, endTime);
      totalSteps =
          discreteTypes.length +
          (windows.length * trackerTypes.length) +
          (Platform.isIOS || Platform.isAndroid ? 1 : 0);

      report('Preparing health data');

      // 1. Fetch discrete health observations (BP, glucose, vitals, sleep, etc.)
      // across the date range. If multi-year queries fail, fallback logic chunks
      // by year to prevent dropping data.
      for (final type in discreteTypes) {
        final typeName = HealthDataRecordMapper.labelFor(type);
        report('Reading $typeName');
        try {
          final typeRecords = await _readDetailedRecords(
            [type],
            effectiveSince,
            endTime,
          );
          records.addAll(typeRecords);
        } catch (e) {
          debugPrint('HealthPlatformImporter: Failed to read $type: $e');
        }
        completedSteps++;
        report('Read $typeName (${records.length} records)');
      }

      // 2. Fetch high-volume continuous tracker data (heart rate, workouts,
      // calories, steps) window-by-window with safe sub-window slicing.
      for (var index = 0; index < windows.length; index++) {
        final window = windows[index];
        final windowRange = sliceLabel(window.start, window.end);

        for (final type in pagedTypes) {
          final typeName = HealthDataRecordMapper.labelFor(type);
          report('Reading $typeName ($windowRange)');
          try {
            final typeRecords = await _readPagedDetailedRecords(
              type,
              window,
              onSlice: (sliceIndex, totalSlices, slice) {
                final sliceName = sliceLabel(slice.start, slice.end);
                report(
                  'Reading $typeName ($sliceName)',
                  stepFraction: sliceIndex / totalSlices,
                );
              },
            );
            records.addAll(typeRecords);
          } catch (_) {
            // If a specific data type fails, proceed with the others.
          }
          completedSteps++;
          report('Read $typeName (${records.length} records)');
        }

        if (calorieTypes.isNotEmpty) {
          report('Reading Calories ($windowRange)');
          try {
            final source = Platform.isIOS ? 'Apple Health' : 'Health Connect';
            final maxDays = maxDaysForType(calorieTypes.first);
            final slices = sliceWindow(window, maxDays: maxDays);
            final aggregatedByType = <HealthDataType, List<HealthRecord>>{
              for (final type in calorieTypes) type: <HealthRecord>[],
            };
            for (var sliceIndex = 0; sliceIndex < slices.length; sliceIndex++) {
              final slice = slices[sliceIndex];
              final sliceName = sliceLabel(slice.start, slice.end);
              report(
                'Reading Calories ($sliceName)',
                stepFraction: sliceIndex / slices.length,
              );
              final points = await _health.getHealthDataFromTypes(
                types: calorieTypes,
                startTime: slice.start,
                endTime: slice.end,
              );
              for (final type in calorieTypes) {
                final samples = points
                    .where((p) => p.type == type)
                    .map((p) => _dailyCalorieSampleFromPoint(p, type))
                    .whereType<DailyCalorieSample>();
                if (samples.isNotEmpty) {
                  aggregatedByType[type]!.addAll(
                    _calorieAggregator.aggregate(
                      samples,
                      type: type,
                      source: source,
                    ),
                  );
                }
              }
            }
            for (final type in calorieTypes) {
              final aggregatedSlices = aggregatedByType[type] ?? const [];
              if (aggregatedSlices.isNotEmpty) {
                records.addAll(
                  DailyCalorieAggregator.combineDailyRecords(aggregatedSlices),
                );
              }
            }
          } catch (_) {}
          completedSteps += calorieTypes.length;
          report('Read Calories (${records.length} records)');
        }

        for (final type in stepTypes) {
          report('Reading Steps ($windowRange)');
          try {
            final source = Platform.isIOS ? 'Apple Health' : 'Health Connect';
            final slices = sliceWindow(window, maxDays: maxDaysForType(type));
            final aggregatedSlices = <HealthRecord>[];
            for (var sliceIndex = 0; sliceIndex < slices.length; sliceIndex++) {
              final slice = slices[sliceIndex];
              final sliceName = sliceLabel(slice.start, slice.end);
              report(
                'Reading Steps ($sliceName)',
                stepFraction: sliceIndex / slices.length,
              );
              final points = await _health.getHealthDataFromTypes(
                types: [type],
                startTime: slice.start,
                endTime: slice.end,
              );
              aggregatedSlices.addAll(
                _stepAggregator.aggregate(
                  points.map(_dailyStepSampleFromPoint),
                  source: source,
                ),
              );
            }
            records.addAll(
              DailyStepAggregator.combineDailyRecords(aggregatedSlices),
            );
          } catch (_) {}
          completedSteps++;
          report('Read Steps (${records.length} records)');
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

  @visibleForTesting
  static int modernEraStartYear({bool? isAndroid, DateTime? now}) {
    // Commercial smartwatches (Apple Watch, Android Wear, Google Fit) launched in 2014-2015.
    // Digital health tracking sensor records exist from 2015 onwards.
    return 2015;
  }

  List<HealthImportWindow> _buildWindows(DateTime since, DateTime until) {
    const modernStartYear = 2015;
    if (since.year < modernStartYear) {
      // Modern electronic health platforms (HealthKit, Health Connect) only have
      // sensor data from the modern smartwatch era (~2014/2015 onwards).
      // Consolidate pre-tracker history into a single historical window so empty
      // historical decades do not execute thousands of redundant slice queries.
      if (until.year > modernStartYear) {
        final modernStart = DateTime(modernStartYear, 1, 1);
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

  @visibleForTesting
  static bool isPagedDetailedType(HealthDataType type) =>
      type == HealthDataType.HEART_RATE ||
      type == HealthDataType.WORKOUT ||
      type == HealthDataType.WORKOUT_ROUTE ||
      type == HealthDataType.DISTANCE_DELTA ||
      type == HealthDataType.DISTANCE_WALKING_RUNNING;

  @visibleForTesting
  static int maxDaysForType(HealthDataType type) {
    switch (type) {
      case HealthDataType.HEART_RATE:
        // Smartwatches record continuous heart rate (every 1-5 seconds),
        // generating high-density raw samples. Slicing into 7-day intervals
        // keeps each payload safely under ~30MB (well below Android's 100MB
        // ByteArrayOutputStream limit) while cutting query overhead in half.
        return 7;
      case HealthDataType.TOTAL_CALORIES_BURNED:
      case HealthDataType.ACTIVE_ENERGY_BURNED:
      case HealthDataType.BASAL_ENERGY_BURNED:
      case HealthDataType.STEPS:
      case HealthDataType.DISTANCE_DELTA:
      case HealthDataType.DISTANCE_WALKING_RUNNING:
        // Continuous fitness tracking produces minute-by-minute energy, distance,
        // and step logs. Slicing into 15-day intervals keeps queries fast and responsive.
        return 15;
      case HealthDataType.WORKOUT:
      case HealthDataType.WORKOUT_ROUTE:
        // Workouts can have detailed route coordinates and exercise samples. Slicing
        // into 30-day intervals prevents freezing on whole years and keeps progress moving.
        return 30;
      default:
        return 30;
    }
  }

  @visibleForTesting
  static String sliceLabel(DateTime start, DateTime end) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (start.year < modernEraStartYear()) {
      return start.year == end.year
          ? '${start.year}'
          : '${start.year}–${end.year}';
    }
    final localStart = start.toLocal();
    final localEnd = end.toLocal();
    final diffDays = end.difference(start).inDays.abs();

    if (diffDays >= 300 ||
        (localStart.month == 1 &&
            localStart.day == 1 &&
            (localEnd.year == localStart.year ||
                (localEnd.year == localStart.year + 1 &&
                    localEnd.month == 1 &&
                    localEnd.day == 1)))) {
      if (localStart.year == localEnd.year) {
        return '${localStart.year}';
      } else if (localEnd.year == localStart.year + 1 &&
          localEnd.month == 1 &&
          localEnd.day == 1) {
        return '${localStart.year}';
      }
      return '${localStart.year}–${localEnd.year}';
    }

    final startMonth = months[localStart.month - 1];
    final endMonth = months[localEnd.month - 1];

    if (diffDays <= 25) {
      if (localStart.year == localEnd.year) {
        if (localStart.month == localEnd.month) {
          return '$startMonth ${localStart.day}–${localEnd.day}, ${localStart.year}';
        } else {
          return '$startMonth ${localStart.day} – $endMonth ${localEnd.day}, ${localStart.year}';
        }
      } else {
        return '$startMonth ${localStart.day}, ${localStart.year} – $endMonth ${localEnd.day}, ${localEnd.year}';
      }
    }

    if (localStart.year == localEnd.year) {
      if (localStart.month == localEnd.month) {
        return '$startMonth ${localStart.year}';
      } else {
        return '$startMonth – $endMonth ${localStart.year}';
      }
    }
    return '$startMonth ${localStart.year} – $endMonth ${localEnd.year}';
  }

  @visibleForTesting
  static List<HealthImportWindow> sliceWindow(
    HealthImportWindow window, {
    int maxDays = 30,
    int? modernStartYear,
  }) {
    // Only slice modern-era windows where dense smartwatch tracking exists.
    // Pre-modern historical windows have no sensor data and should execute
    // in a single fast query.
    final thresholdYear = modernStartYear ?? modernEraStartYear();
    if (window.start.year < thresholdYear ||
        window.end.difference(window.start).inDays <= maxDays) {
      return [window];
    }
    final slices = <HealthImportWindow>[];
    var current = window.start;
    final isUtc = current.isUtc;
    while (current.isBefore(window.end)) {
      var next = isUtc
          ? DateTime.utc(
              current.year,
              current.month,
              current.day + maxDays,
              current.hour,
              current.minute,
              current.second,
            )
          : DateTime(
              current.year,
              current.month,
              current.day + maxDays,
              current.hour,
              current.minute,
              current.second,
            );
      if (next.isAfter(window.end)) {
        next = window.end;
      }
      slices.add(HealthImportWindow(current, next));
      current = next;
    }
    return slices;
  }

  Future<List<HealthRecord>> _readPagedDetailedRecords(
    HealthDataType type,
    HealthImportWindow window, {
    required void Function(
      int sliceIndex,
      int totalSlices,
      HealthImportWindow slice,
    )
    onSlice,
  }) async {
    final fallbackSource = Platform.isIOS ? 'Apple Health' : 'Health Connect';
    final slices = sliceWindow(window, maxDays: maxDaysForType(type));
    final accumulated = <HealthRecord>[];
    DateTime? lastHeartRateTime;
    for (var i = 0; i < slices.length; i++) {
      final slice = slices[i];
      onSlice(i, slices.length, slice);
      try {
        final points = await _health.getHealthDataFromTypes(
          types: [type],
          startTime: slice.start,
          endTime: slice.end,
        );
        final (filtered, updatedLastTime) = _downsampleHeartRateIfNeeded(
          points,
          [type],
          lastSampledTime: lastHeartRateTime,
        );
        lastHeartRateTime = updatedLastTime;
        accumulated.addAll(
          filtered.map(
            (point) =>
                _recordMapper.mapPoint(point, fallbackSource: fallbackSource),
          ),
        );
      } catch (_) {
        // Continue with remaining slices if a single slice fails.
      }
    }
    return accumulated;
  }

  Future<List<HealthRecord>> _readDetailedRecords(
    List<HealthDataType> types,
    DateTime startTime,
    DateTime endTime,
  ) async {
    final fallbackSource = Platform.isIOS ? 'Apple Health' : 'Health Connect';
    try {
      final points = await _health.getHealthDataFromTypes(
        types: types,
        startTime: startTime,
        endTime: endTime,
      );
      final (filtered, _) = _downsampleHeartRateIfNeeded(points, types);
      return filtered
          .map(
            (point) =>
                _recordMapper.mapPoint(point, fallbackSource: fallbackSource),
          )
          .toList();
    } catch (e) {
      debugPrint(
        'HealthPlatformImporter: Failed to read $types in single query: $e',
      );
      if (endTime.difference(startTime).inDays > 365) {
        final fallbackRecords = <HealthRecord>[];
        final yearlyWindows = buildHealthImportWindows(
          since: startTime,
          until: endTime,
          batchYears: 1,
        );
        for (final window in yearlyWindows) {
          try {
            final points = await _health.getHealthDataFromTypes(
              types: types,
              startTime: window.start,
              endTime: window.end,
            );
            final (filtered, _) = _downsampleHeartRateIfNeeded(points, types);
            fallbackRecords.addAll(
              filtered.map(
                (point) => _recordMapper.mapPoint(
                  point,
                  fallbackSource: fallbackSource,
                ),
              ),
            );
          } catch (inner) {
            debugPrint(
              'HealthPlatformImporter: Fallback yearly slice failed for $types: $inner',
            );
          }
        }
        return fallbackRecords;
      }
      return const [];
    }
  }

  (List<HealthDataPoint>, DateTime?) _downsampleHeartRateIfNeeded(
    List<HealthDataPoint> points,
    List<HealthDataType> types, {
    DateTime? lastSampledTime,
  }) {
    if (!types.contains(HealthDataType.HEART_RATE) || points.isEmpty) {
      return (points, lastSampledTime);
    }
    // High-frequency continuous heart rate tracking on smartwatches records
    // readings every few seconds, generating hundreds of thousands of raw samples.
    // Downsample to at most one sample per 10 minutes to maintain clinical
    // trend utility without exhausting device memory or storage.
    final heartRatePoints = <HealthDataPoint>[];
    final otherPoints = <HealthDataPoint>[];
    for (final point in points) {
      if (point.type == HealthDataType.HEART_RATE) {
        heartRatePoints.add(point);
      } else {
        otherPoints.add(point);
      }
    }
    heartRatePoints.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
    final sampled = <HealthDataPoint>[];
    var lastTime = lastSampledTime;
    for (final point in heartRatePoints) {
      if (lastTime == null ||
          point.dateFrom.difference(lastTime).inMinutes.abs() >= 10) {
        sampled.add(point);
        lastTime = point.dateFrom;
      }
    }
    return ([...otherPoints, ...sampled], lastTime);
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

  DailyCalorieSample? _dailyCalorieSampleFromPoint(
    HealthDataPoint point,
    HealthDataType type,
  ) {
    final value = point.value.toJson()['numericValue'];
    if (value is! num) return null;
    return DailyCalorieSample(
      recordedAt: point.dateFrom,
      calories: value,
      type: type,
    );
  }
}

class HealthChangesResult {
  const HealthChangesResult({
    required this.records,
    required this.nextChangesToken,
    this.deletedRecordIds = const [],
  });

  final List<HealthRecord> records;
  final String nextChangesToken;
  final List<String> deletedRecordIds;
}
