import 'dart:io';

import 'package:health/health.dart';
import 'package:flutter/foundation.dart';

import '../models/health_record.dart';
import 'apple_clinical_records_importer.dart';
import 'health_data_record_mapper.dart';
import 'health_connect_medical_records_importer.dart';
import 'health_import_windows.dart';
import 'workout_activity_aggregator.dart';
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
  final _workoutActivityAggregator = const WorkoutActivityAggregator();
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

    // Process workouts and aggregatable activity metrics (steps, distance,
    // calories, flights climbed) so metrics belonging to a workout aggregate
    // onto the workout and remaining metrics aggregate daily.
    final upsertedWorkouts = allUpsertedPoints
        .where((point) => point.type == HealthDataType.WORKOUT)
        .toList();
    final upsertedActivityPoints = allUpsertedPoints
        .where(
          (point) =>
              WorkoutActivityAggregator.isAggregatableActivityType(point.type),
        )
        .toList();

    final processedWorkoutUuids = <String>{};
    if (upsertedActivityPoints.isNotEmpty) {
      final affectedDays = upsertedActivityPoints
          .map(
            (p) => DateTime(p.dateFrom.year, p.dateFrom.month, p.dateFrom.day),
          )
          .toSet();
      for (final day in affectedDays) {
        final start = DateTime(day.year, day.month, day.day);
        final end = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);
        final dayActivityTypes = upsertedActivityPoints
            .where(
              (p) =>
                  p.dateFrom.year == day.year &&
                  p.dateFrom.month == day.month &&
                  p.dateFrom.day == day.day,
            )
            .map((p) => p.type)
            .toSet()
            .toList();

        var dayWorkouts = upsertedWorkouts
            .where((w) => !w.dateTo.isBefore(start) && !w.dateFrom.isAfter(end))
            .toList();
        try {
          dayWorkouts = await _health.getHealthDataFromTypes(
            types: const [HealthDataType.WORKOUT],
            startTime: start,
            endTime: end,
          );
        } catch (_) {}

        var dayActivityPoints = upsertedActivityPoints
            .where(
              (p) =>
                  p.dateFrom.year == day.year &&
                  p.dateFrom.month == day.month &&
                  p.dateFrom.day == day.day,
            )
            .toList();
        try {
          dayActivityPoints = await _health.getHealthDataFromTypes(
            types: dayActivityTypes,
            startTime: start,
            endTime: end,
          );
        } catch (_) {}

        for (final w in dayWorkouts) {
          processedWorkoutUuids.add(w.uuid);
        }
        final aggregation = _workoutActivityAggregator.aggregate(
          workouts: dayWorkouts,
          activityPoints: dayActivityPoints,
          fallbackSource: 'Health Connect',
        );
        records.addAll(aggregation.workoutRecords);
        records.addAll(aggregation.dailyRecords);
      }
    }

    final remainingWorkouts = upsertedWorkouts
        .where((w) => !processedWorkoutUuids.contains(w.uuid))
        .toList();
    for (final workout in remainingWorkouts) {
      var workoutActivityPoints = <HealthDataPoint>[];
      try {
        workoutActivityPoints = await _health.getHealthDataFromTypes(
          types: const [
            HealthDataType.DISTANCE_DELTA,
            HealthDataType.DISTANCE_WALKING_RUNNING,
            HealthDataType.ACTIVE_ENERGY_BURNED,
            HealthDataType.TOTAL_CALORIES_BURNED,
            HealthDataType.STEPS,
            HealthDataType.FLIGHTS_CLIMBED,
          ],
          startTime: workout.dateFrom,
          endTime: workout.dateTo,
        );
      } catch (_) {}
      final aggregation = _workoutActivityAggregator.aggregate(
        workouts: [workout],
        activityPoints: workoutActivityPoints,
        fallbackSource: 'Health Connect',
      );
      records.addAll(aggregation.workoutRecords);
    }

    // Process other points (discrete vitals, sleep, downsampled heart rate)
    final otherPoints = allUpsertedPoints
        .where(
          (point) =>
              point.type != HealthDataType.WORKOUT &&
              !WorkoutActivityAggregator.isAggregatableActivityType(point.type),
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
      final distanceTypes = availableTypes.where(isDistanceType).toList();
      final flightsTypes = availableTypes
          .where((type) => type == HealthDataType.FLIGHTS_CLIMBED)
          .toList();
      final pagedTypes = availableTypes
          .where((type) => isPagedDetailedType(type) && !isDistanceType(type))
          .toList();
      final discreteTypes = availableTypes
          .where(
            (type) =>
                type != HealthDataType.STEPS &&
                type != HealthDataType.FLIGHTS_CLIMBED &&
                !isCalorieType(type) &&
                !isDistanceType(type) &&
                !isPagedDetailedType(type),
          )
          .toList();

      final trackerTypes = [
        ...pagedTypes,
        ...distanceTypes,
        ...calorieTypes,
        ...stepTypes,
        ...flightsTypes,
      ];
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
      // distance, calories, steps, flights climbed) window-by-window with safe
      // sub-window slicing, aggregating workout-associated metrics onto workouts
      // and remaining metrics daily.
      for (var index = 0; index < windows.length; index++) {
        final window = windows[index];
        final windowRange = sliceLabel(window.start, window.end);
        final source = Platform.isIOS ? 'Apple Health' : 'Health Connect';
        final windowWorkoutPoints = <HealthDataPoint>[];
        final windowActivityPoints = <HealthDataPoint>[];

        for (final type in pagedTypes) {
          final typeName = HealthDataRecordMapper.labelFor(type);
          report('Reading $typeName ($windowRange)');
          try {
            if (type == HealthDataType.WORKOUT) {
              final slices = sliceWindow(window, maxDays: maxDaysForType(type));
              for (
                var sliceIndex = 0;
                sliceIndex < slices.length;
                sliceIndex++
              ) {
                final slice = slices[sliceIndex];
                final sliceName = sliceLabel(slice.start, slice.end);
                report(
                  'Reading $typeName ($sliceName)',
                  stepFraction: sliceIndex / slices.length,
                );
                try {
                  final points = await _health.getHealthDataFromTypes(
                    types: [type],
                    startTime: slice.start,
                    endTime: slice.end,
                  );
                  windowWorkoutPoints.addAll(points);
                } catch (_) {}
              }
            } else {
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
            }
          } catch (_) {
            // If a specific data type fails, proceed with the others.
          }
          completedSteps++;
          report('Read $typeName (${records.length} records)');
        }

        for (final type in distanceTypes) {
          final typeName = HealthDataRecordMapper.labelFor(type);
          report('Reading $typeName ($windowRange)');
          try {
            final slices = sliceWindow(window, maxDays: maxDaysForType(type));
            for (var sliceIndex = 0; sliceIndex < slices.length; sliceIndex++) {
              final slice = slices[sliceIndex];
              final sliceName = sliceLabel(slice.start, slice.end);
              report(
                'Reading $typeName ($sliceName)',
                stepFraction: sliceIndex / slices.length,
              );
              try {
                final points = await _health.getHealthDataFromTypes(
                  types: [type],
                  startTime: slice.start,
                  endTime: slice.end,
                );
                windowActivityPoints.addAll(points);
              } catch (_) {}
            }
          } catch (_) {}
          completedSteps++;
          report('Read $typeName (${records.length} records)');
        }

        if (calorieTypes.isNotEmpty) {
          report('Reading Calories ($windowRange)');
          try {
            final maxDays = maxDaysForType(calorieTypes.first);
            final slices = sliceWindow(window, maxDays: maxDays);
            for (var sliceIndex = 0; sliceIndex < slices.length; sliceIndex++) {
              final slice = slices[sliceIndex];
              final sliceName = sliceLabel(slice.start, slice.end);
              report(
                'Reading Calories ($sliceName)',
                stepFraction: sliceIndex / slices.length,
              );
              try {
                final points = await _health.getHealthDataFromTypes(
                  types: calorieTypes,
                  startTime: slice.start,
                  endTime: slice.end,
                );
                windowActivityPoints.addAll(points);
              } catch (_) {}
            }
          } catch (_) {}
          completedSteps += calorieTypes.length;
          report('Read Calories (${records.length} records)');
        }

        for (final type in stepTypes) {
          report('Reading Steps ($windowRange)');
          try {
            final slices = sliceWindow(window, maxDays: maxDaysForType(type));
            for (var sliceIndex = 0; sliceIndex < slices.length; sliceIndex++) {
              final slice = slices[sliceIndex];
              final sliceName = sliceLabel(slice.start, slice.end);
              report(
                'Reading Steps ($sliceName)',
                stepFraction: sliceIndex / slices.length,
              );
              try {
                final points = await _health.getHealthDataFromTypes(
                  types: [type],
                  startTime: slice.start,
                  endTime: slice.end,
                );
                windowActivityPoints.addAll(points);
              } catch (_) {}
            }
          } catch (_) {}
          completedSteps++;
          report('Read Steps (${records.length} records)');
        }

        for (final type in flightsTypes) {
          final typeName = HealthDataRecordMapper.labelFor(type);
          report('Reading $typeName ($windowRange)');
          try {
            final slices = sliceWindow(window, maxDays: maxDaysForType(type));
            for (var sliceIndex = 0; sliceIndex < slices.length; sliceIndex++) {
              final slice = slices[sliceIndex];
              final sliceName = sliceLabel(slice.start, slice.end);
              report(
                'Reading $typeName ($sliceName)',
                stepFraction: sliceIndex / slices.length,
              );
              try {
                final points = await _health.getHealthDataFromTypes(
                  types: [type],
                  startTime: slice.start,
                  endTime: slice.end,
                );
                windowActivityPoints.addAll(points);
              } catch (_) {}
            }
          } catch (_) {}
          completedSteps++;
          report('Read $typeName (${records.length} records)');
        }

        if (windowWorkoutPoints.isNotEmpty || windowActivityPoints.isNotEmpty) {
          final aggregation = _workoutActivityAggregator.aggregate(
            workouts: windowWorkoutPoints,
            activityPoints: windowActivityPoints,
            fallbackSource: source,
          );
          records.addAll(aggregation.workoutRecords);
          records.addAll(
            WorkoutActivityAggregator.combineDailyRecords(
              aggregation.dailyRecords,
            ),
          );
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
  static bool isDistanceType(HealthDataType type) =>
      WorkoutActivityAggregator.isDistanceType(type);

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
      case HealthDataType.FLIGHTS_CLIMBED:
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
