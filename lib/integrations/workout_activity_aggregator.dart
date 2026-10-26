import 'package:health/health.dart';

import '../models/health_record.dart';
import 'daily_calorie_aggregator.dart';
import 'daily_distance_aggregator.dart';
import 'daily_step_aggregator.dart';
import 'health_data_record_mapper.dart';

/// Aggregates activity samples (distance, steps, calories, flights climbed)
/// onto their associated workout when recorded during a workout, and aggregates
/// remaining unassociated samples into daily totals.
class WorkoutActivityAggregator {
  const WorkoutActivityAggregator({
    DailyDistanceAggregator distanceAggregator =
        const DailyDistanceAggregator(),
    DailyCalorieAggregator calorieAggregator = const DailyCalorieAggregator(),
    DailyStepAggregator stepAggregator = const DailyStepAggregator(),
    HealthDataRecordMapper recordMapper = const HealthDataRecordMapper(),
  }) : _distanceAggregator = distanceAggregator,
       _calorieAggregator = calorieAggregator,
       _stepAggregator = stepAggregator,
       _recordMapper = recordMapper;

  final DailyDistanceAggregator _distanceAggregator;
  final DailyCalorieAggregator _calorieAggregator;
  final DailyStepAggregator _stepAggregator;
  final HealthDataRecordMapper _recordMapper;

  static bool isDistanceType(HealthDataType type) =>
      type == HealthDataType.DISTANCE_DELTA ||
      type == HealthDataType.DISTANCE_WALKING_RUNNING;

  static bool isCalorieType(HealthDataType type) =>
      type == HealthDataType.ACTIVE_ENERGY_BURNED ||
      type == HealthDataType.BASAL_ENERGY_BURNED ||
      type == HealthDataType.TOTAL_CALORIES_BURNED;

  static bool isAggregatableActivityType(HealthDataType type) =>
      isDistanceType(type) ||
      isCalorieType(type) ||
      type == HealthDataType.STEPS ||
      type == HealthDataType.FLIGHTS_CLIMBED;

  /// Finds the workout in [workouts] that [sample] belongs to, or `null` if
  /// [sample] is not associated with any workout.
  static HealthDataPoint? findAssociatedWorkout(
    HealthDataPoint sample,
    Iterable<HealthDataPoint> workouts,
  ) {
    // 1. Check explicit workout UUID metadata link first.
    final meta = sample.metadata;
    final linkedUuid =
        (meta?['workoutUuid'] ?? meta?['workout_uuid'] ?? meta?['workoutId'])
            as String?;
    if (linkedUuid != null && linkedUuid.isNotEmpty) {
      for (final workout in workouts) {
        if (workout.type == HealthDataType.WORKOUT &&
            workout.uuid == linkedUuid) {
          return workout;
        }
      }
    }

    // Basal energy burned is resting metabolic rate and should only attach to
    // a workout if explicitly linked via metadata.
    if (sample.type == HealthDataType.BASAL_ENERGY_BURNED) {
      return null;
    }

    // 2. Check time window overlap: sample midpoint within [workout.dateFrom, workout.dateTo]
    // and sample duration not dramatically longer than the workout itself (so full-day
    // summary samples are not swallowed by a short workout).
    final sampleStart = sample.dateFrom.toUtc();
    final sampleEnd = sample.dateTo.toUtc();
    final sampleDurationMs = sampleEnd
        .difference(sampleStart)
        .inMilliseconds
        .abs();
    final sampleMid = sampleStart.add(
      Duration(milliseconds: sampleDurationMs ~/ 2),
    );

    for (final workout in workouts) {
      if (workout.type != HealthDataType.WORKOUT) continue;
      final wStart = workout.dateFrom.toUtc();
      final wEnd = workout.dateTo.toUtc();
      final wDurationMs = wEnd.difference(wStart).inMilliseconds.abs();
      final maxAllowedSampleMs =
          wDurationMs + const Duration(minutes: 15).inMilliseconds;
      if (sampleDurationMs <= maxAllowedSampleMs &&
          !sampleMid.isBefore(wStart) &&
          !sampleMid.isAfter(wEnd)) {
        return workout;
      }
    }
    return null;
  }

  /// Fast helper to match samples against pre-computed workout time windows and UUID map,
  /// avoiding O(N * M) repeated DateTime conversions and list allocations.
  static HealthDataPoint? _findAssociatedWorkoutFast(
    HealthDataPoint sample,
    Map<String, HealthDataPoint> workoutsByUuid,
    List<_WorkoutWindow> workoutWindows,
  ) {
    if (workoutWindows.isEmpty) return null;

    final meta = sample.metadata;
    final linkedUuid =
        (meta?['workoutUuid'] ?? meta?['workout_uuid'] ?? meta?['workoutId'])
            as String?;
    if (linkedUuid != null && linkedUuid.isNotEmpty) {
      final linkedWorkout = workoutsByUuid[linkedUuid];
      if (linkedWorkout != null) return linkedWorkout;
    }

    if (sample.type == HealthDataType.BASAL_ENERGY_BURNED) {
      return null;
    }

    final sampleStart = sample.dateFrom.toUtc();
    final sampleEnd = sample.dateTo.toUtc();
    final sampleDurationMs = sampleEnd
        .difference(sampleStart)
        .inMilliseconds
        .abs();
    final sampleMid = sampleStart.add(
      Duration(milliseconds: sampleDurationMs ~/ 2),
    );

    for (var i = 0; i < workoutWindows.length; i++) {
      final window = workoutWindows[i];
      if (sampleDurationMs <= window.maxAllowedSampleMs &&
          !sampleMid.isBefore(window.start) &&
          !sampleMid.isAfter(window.end)) {
        return window.workout;
      }
    }
    return null;
  }

  /// Processes [workouts] and [activityPoints], returning:
  /// - Workout [HealthRecord]s enriched with any activity metrics recorded during each workout.
  /// - Daily aggregated [HealthRecord]s for all activity metrics not associated with a workout.
  WorkoutAndDailyAggregationResult aggregate({
    required List<HealthDataPoint> workouts,
    required Iterable<HealthDataPoint> activityPoints,
    required String fallbackSource,
  }) {
    final workoutBuckets = <String, _WorkoutMetricBucket>{};
    final orderedWorkouts = <HealthDataPoint>[];
    final workoutWindows = <_WorkoutWindow>[];
    final workoutsByUuid = <String, HealthDataPoint>{};

    for (final workout in workouts) {
      if (workout.type != HealthDataType.WORKOUT) continue;
      final key = '${workout.sourceId}:${workout.uuid}';
      if (!workoutBuckets.containsKey(key)) {
        workoutBuckets[key] = _WorkoutMetricBucket(workout);
        orderedWorkouts.add(workout);
        workoutWindows.add(_WorkoutWindow(workout));
        if (workout.uuid.isNotEmpty) {
          workoutsByUuid.putIfAbsent(workout.uuid, () => workout);
        }
      }
    }

    final unassociatedDistanceByType =
        <HealthDataType, List<DailyDistanceSample>>{};
    final unassociatedCaloriesByType =
        <HealthDataType, List<DailyCalorieSample>>{};
    final unassociatedSteps = <DailyStepSample>[];
    final unassociatedFlights = <_DailyFlightSample>[];

    for (final point in activityPoints) {
      final numValue = _numericValue(point);
      if (numValue == null) continue;

      final matchedWorkout = _findAssociatedWorkoutFast(
        point,
        workoutsByUuid,
        workoutWindows,
      );
      if (matchedWorkout != null) {
        final key = '${matchedWorkout.sourceId}:${matchedWorkout.uuid}';
        final bucket = workoutBuckets[key];
        if (bucket != null) {
          bucket.addSample(point, numValue);
          continue;
        }
      }

      if (isDistanceType(point.type)) {
        final meters = DailyDistanceAggregator.toMeters(numValue, point.unit);
        (unassociatedDistanceByType[point.type] ??= <DailyDistanceSample>[])
            .add(
              DailyDistanceSample(
                recordedAt: point.dateFrom,
                distanceMeters: meters,
                type: point.type,
              ),
            );
      } else if (isCalorieType(point.type)) {
        (unassociatedCaloriesByType[point.type] ??= <DailyCalorieSample>[]).add(
          DailyCalorieSample(
            recordedAt: point.dateFrom,
            calories: numValue,
            type: point.type,
          ),
        );
      } else if (point.type == HealthDataType.STEPS) {
        unassociatedSteps.add(
          DailyStepSample(recordedAt: point.dateFrom, steps: numValue),
        );
      } else if (point.type == HealthDataType.FLIGHTS_CLIMBED) {
        unassociatedFlights.add(
          _DailyFlightSample(recordedAt: point.dateFrom, flights: numValue),
        );
      }
    }

    final workoutRecords = <HealthRecord>[
      for (final workout in orderedWorkouts)
        _buildWorkoutRecord(
          workoutBuckets['${workout.sourceId}:${workout.uuid}']!,
          fallbackSource: fallbackSource,
        ),
    ];

    final dailyRecords = <HealthRecord>[];
    for (final entry in unassociatedDistanceByType.entries) {
      if (entry.value.isNotEmpty) {
        dailyRecords.addAll(
          _distanceAggregator.aggregate(
            entry.value,
            type: entry.key,
            source: fallbackSource,
          ),
        );
      }
    }
    for (final entry in unassociatedCaloriesByType.entries) {
      if (entry.value.isNotEmpty) {
        dailyRecords.addAll(
          _calorieAggregator.aggregate(
            entry.value,
            type: entry.key,
            source: fallbackSource,
          ),
        );
      }
    }
    if (unassociatedSteps.isNotEmpty) {
      dailyRecords.addAll(
        _stepAggregator.aggregate(unassociatedSteps, source: fallbackSource),
      );
    }
    if (unassociatedFlights.isNotEmpty) {
      dailyRecords.addAll(
        _aggregateDailyFlights(unassociatedFlights, source: fallbackSource),
      );
    }

    return WorkoutAndDailyAggregationResult(
      workoutRecords: workoutRecords,
      dailyRecords: dailyRecords,
    );
  }

  HealthRecord _buildWorkoutRecord(
    _WorkoutMetricBucket bucket, {
    required String fallbackSource,
  }) {
    final point = bucket.workout;
    final baseRecord = _recordMapper.mapPoint(
      point,
      fallbackSource: fallbackSource,
    );
    if (!bucket.hasAggregatedSamples) {
      return baseRecord;
    }

    final workoutValue = point.value is WorkoutHealthValue
        ? point.value as WorkoutHealthValue
        : null;

    final activityName =
        workoutValue?.workoutActivityType.name
            .replaceAll('_', ' ')
            .toLowerCase() ??
        'workout';

    final details = <String>[activityName];

    // Energy burned (kcal)
    final existingEnergy = workoutValue?.totalEnergyBurned;
    final effectiveEnergy = (existingEnergy != null && existingEnergy > 0)
        ? existingEnergy.toDouble()
        : bucket.effectiveCaloriesKcal;
    if (effectiveEnergy > 0) {
      details.add('${formatSensibleNumber(effectiveEnergy)} kcal');
    }

    // Distance (m)
    final existingDistance = workoutValue?.totalDistance;
    final effectiveDistance = (existingDistance != null && existingDistance > 0)
        ? existingDistance.toDouble()
        : bucket.distanceMeters;
    if (effectiveDistance > 0) {
      details.add('${formatSensibleNumber(effectiveDistance)} m');
    }

    // Steps
    final existingSteps = workoutValue?.totalSteps;
    final effectiveSteps = (existingSteps != null && existingSteps > 0)
        ? existingSteps.toInt()
        : bucket.steps.round();
    if (effectiveSteps > 0) {
      details.add('${formatSensibleNumber(effectiveSteps)} steps');
    }

    // Flights climbed
    final effectiveFlights = bucket.flightsClimbed.round();
    if (effectiveFlights > 0) {
      details.add('${formatSensibleNumber(effectiveFlights)} flights');
    }

    final aggregatedMetrics = <String, Object?>{
      if (bucket.distanceSampleCount > 0) ...{
        'distanceMeters': bucket.distanceMeters,
        'distanceSampleCount': bucket.distanceSampleCount,
      },
      if (bucket.calorieSampleCount > 0) ...{
        'caloriesKcal': bucket.effectiveCaloriesKcal,
        'calorieSampleCount': bucket.calorieSampleCount,
      },
      if (bucket.stepSampleCount > 0) ...{
        'steps': bucket.steps.round(),
        'stepSampleCount': bucket.stepSampleCount,
      },
      if (bucket.flightsSampleCount > 0) ...{
        'flightsClimbed': bucket.flightsClimbed.round(),
        'flightsSampleCount': bucket.flightsSampleCount,
      },
    };

    return baseRecord.copyWith(
      value: details.join(' · '),
      status: 'Workout (aggregated)',
      sourceData: {
        ...?baseRecord.sourceData,
        'aggregatedWorkoutMetrics': aggregatedMetrics,
      },
    );
  }

  List<HealthRecord> _aggregateDailyFlights(
    Iterable<_DailyFlightSample> samples, {
    required String source,
  }) {
    final totals = <DateTime, (double, int)>{};
    for (final sample in samples) {
      final local = sample.recordedAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      final current = totals[day];
      if (current == null) {
        totals[day] = (sample.flights.toDouble(), 1);
      } else {
        totals[day] = (current.$1 + sample.flights.toDouble(), current.$2 + 1);
      }
    }
    final days = totals.keys.toList()..sort();
    return [
      for (final day in days)
        HealthRecord(
          id: 'health:flights_climbed:daily:${_dateKey(day)}',
          name: 'Flights climbed',
          value: totals[day]!.$1.round().toString(),
          unit: 'count',
          recordedAt: DateTime(day.year, day.month, day.day, 12).toUtc(),
          category: RecordCategory.activity,
          source: source,
          sourceId: 'daily-total',
          code: 'FLIGHTS_CLIMBED',
          status: 'Daily total (aggregated)',
          sourceData: {
            'aggregation': 'daily-total',
            'type': 'FLIGHTS_CLIMBED',
            'sampleCount': totals[day]!.$2,
          },
        ),
    ];
  }

  static List<HealthRecord> combineDailyRecords(List<HealthRecord> records) {
    final byId = <String, HealthRecord>{};
    for (final record in records) {
      final existing = byId[record.id];
      if (existing == null) {
        byId[record.id] = record;
      } else {
        final val1 = double.tryParse(existing.value) ?? 0.0;
        final val2 = double.tryParse(record.value) ?? 0.0;
        final count1 =
            (existing.sourceData?['sampleCount'] as num?)?.toInt() ?? 1;
        final count2 =
            (record.sourceData?['sampleCount'] as num?)?.toInt() ?? 1;
        final isIntegerCount = record.unit == 'count';
        final mergedValue = isIntegerCount
            ? (val1 + val2).round().toString()
            : formatSensibleNumber(val1 + val2);
        byId[record.id] = existing.copyWith(
          value: mergedValue,
          sourceData: {...?existing.sourceData, 'sampleCount': count1 + count2},
        );
      }
    }
    return byId.values.toList();
  }

  static num? _numericValue(HealthDataPoint point) {
    final value = point.value.toJson()['numericValue'];
    return value is num ? value : null;
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class WorkoutAndDailyAggregationResult {
  const WorkoutAndDailyAggregationResult({
    required this.workoutRecords,
    required this.dailyRecords,
  });

  final List<HealthRecord> workoutRecords;
  final List<HealthRecord> dailyRecords;

  List<HealthRecord> get allRecords => [...workoutRecords, ...dailyRecords];
}

class _WorkoutMetricBucket {
  _WorkoutMetricBucket(this.workout);

  final HealthDataPoint workout;
  double distanceMeters = 0;
  int distanceSampleCount = 0;
  double activeCaloriesKcal = 0;
  int activeCalorieSampleCount = 0;
  double totalCaloriesKcal = 0;
  int totalCalorieSampleCount = 0;
  double steps = 0;
  int stepSampleCount = 0;
  double flightsClimbed = 0;
  int flightsSampleCount = 0;

  bool get hasAggregatedSamples =>
      distanceSampleCount > 0 ||
      calorieSampleCount > 0 ||
      stepSampleCount > 0 ||
      flightsSampleCount > 0;

  double get effectiveCaloriesKcal =>
      activeCalorieSampleCount > 0 ? activeCaloriesKcal : totalCaloriesKcal;

  int get calorieSampleCount => activeCalorieSampleCount > 0
      ? activeCalorieSampleCount
      : totalCalorieSampleCount;

  void addSample(HealthDataPoint point, num numericValue) {
    if (WorkoutActivityAggregator.isDistanceType(point.type)) {
      distanceMeters += DailyDistanceAggregator.toMeters(
        numericValue,
        point.unit,
      );
      distanceSampleCount++;
    } else if (point.type == HealthDataType.ACTIVE_ENERGY_BURNED) {
      activeCaloriesKcal += numericValue.toDouble();
      activeCalorieSampleCount++;
    } else if (point.type == HealthDataType.TOTAL_CALORIES_BURNED) {
      totalCaloriesKcal += numericValue.toDouble();
      totalCalorieSampleCount++;
    } else if (point.type == HealthDataType.STEPS) {
      steps += numericValue.toDouble();
      stepSampleCount++;
    } else if (point.type == HealthDataType.FLIGHTS_CLIMBED) {
      flightsClimbed += numericValue.toDouble();
      flightsSampleCount++;
    }
  }
}

class _DailyFlightSample {
  const _DailyFlightSample({required this.recordedAt, required this.flights});

  final DateTime recordedAt;
  final num flights;
}

/// Pre-computed workout time window boundaries to avoid re-parsing dates and
/// calculating max durations for every activity sample point during aggregation.
class _WorkoutWindow {
  _WorkoutWindow(this.workout)
    : start = workout.dateFrom.toUtc(),
      end = workout.dateTo.toUtc(),
      maxAllowedSampleMs =
          workout.dateTo
              .toUtc()
              .difference(workout.dateFrom.toUtc())
              .inMilliseconds
              .abs() +
          const Duration(minutes: 15).inMilliseconds;

  final HealthDataPoint workout;
  final DateTime start;
  final DateTime end;
  final int maxAllowedSampleMs;
}
