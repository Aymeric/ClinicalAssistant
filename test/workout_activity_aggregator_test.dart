import 'package:clinical_assistant/integrations/daily_distance_aggregator.dart';
import 'package:clinical_assistant/integrations/workout_activity_aggregator.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/ui/overview/overview_page.dart';
import 'package:clinical_assistant/ui/shared/record_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

void main() {
  group('DailyDistanceAggregator', () {
    const aggregator = DailyDistanceAggregator();

    test(
      'combines distance samples into one daily record per day per type',
      () {
        final records = aggregator.aggregate(
          [
            DailyDistanceSample(
              recordedAt: DateTime(2026, 9, 25, 8, 30),
              distanceMeters: 1200.5,
              type: HealthDataType.DISTANCE_DELTA,
            ),
            DailyDistanceSample(
              recordedAt: DateTime(2026, 9, 25, 18, 15),
              distanceMeters: 799.5,
              type: HealthDataType.DISTANCE_DELTA,
            ),
            DailyDistanceSample(
              recordedAt: DateTime(2026, 9, 26, 9, 0),
              distanceMeters: 3500,
              type: HealthDataType.DISTANCE_DELTA,
            ),
          ],
          type: HealthDataType.DISTANCE_DELTA,
          source: 'Health Connect',
        );

        expect(records, hasLength(2));
        expect(records.first.id, 'health:distance_delta:daily:2026-09-25');
        expect(records.first.name, 'Distance');
        expect(records.first.value, '2000');
        expect(records.first.unit, 'm');
        expect(records.first.status, 'Daily total (aggregated)');
        expect(records.first.sourceData, {
          'aggregation': 'daily-total',
          'type': 'DISTANCE_DELTA',
          'sampleCount': 2,
        });
        expect(records.last.id, 'health:distance_delta:daily:2026-09-26');
        expect(records.last.value, '3500');
      },
    );

    test('converts centimeters and miles to meters', () {
      expect(DailyDistanceAggregator.toMeters(250, HealthDataUnit.METER), 250);
      expect(
        DailyDistanceAggregator.toMeters(150, HealthDataUnit.CENTIMETER),
        1.5,
      );
      expect(
        DailyDistanceAggregator.toMeters(1, HealthDataUnit.MILE),
        closeTo(1609.344, 0.001),
      );
    });

    test('combineDailyRecords merges slices sharing the same daily ID', () {
      final batch1 = aggregator.aggregate(
        [
          DailyDistanceSample(
            recordedAt: DateTime(2026, 9, 25, 8, 0),
            distanceMeters: 800,
            type: HealthDataType.DISTANCE_WALKING_RUNNING,
          ),
        ],
        type: HealthDataType.DISTANCE_WALKING_RUNNING,
        source: 'Apple Health',
      );
      final batch2 = aggregator.aggregate(
        [
          DailyDistanceSample(
            recordedAt: DateTime(2026, 9, 25, 19, 0),
            distanceMeters: 1450,
            type: HealthDataType.DISTANCE_WALKING_RUNNING,
          ),
        ],
        type: HealthDataType.DISTANCE_WALKING_RUNNING,
        source: 'Apple Health',
      );

      final combined = DailyDistanceAggregator.combineDailyRecords([
        ...batch1,
        ...batch2,
      ]);
      expect(combined, hasLength(1));
      expect(
        combined.first.id,
        'health:distance_walking_running:daily:2026-09-25',
      );
      expect(combined.first.value, '2250');
      expect(combined.first.sourceData?['sampleCount'], 2);
    });
  });

  group('WorkoutActivityAggregator', () {
    const aggregator = WorkoutActivityAggregator();

    test(
      'aggregates distance, calories, steps, and flights climbed during a workout onto the workout and aggregates remaining samples daily',
      () {
        final workoutStart = DateTime(2026, 9, 25, 7, 0);
        final workoutEnd = DateTime(2026, 9, 25, 7, 45);
        final workout = _point(
          uuid: 'workout-run-1',
          type: HealthDataType.WORKOUT,
          value: WorkoutHealthValue(
            workoutActivityType: HealthWorkoutActivityType.RUNNING,
            totalEnergyBurned: 0,
            totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
            totalDistance: 0,
            totalDistanceUnit: HealthDataUnit.METER,
            totalSteps: 0,
            totalStepsUnit: HealthDataUnit.COUNT,
          ),
          dateFrom: workoutStart,
          dateTo: workoutEnd,
        );

        final activityPoints = <HealthDataPoint>[
          // During workout (by time window):
          _point(
            uuid: 'dist-workout-1',
            type: HealthDataType.DISTANCE_WALKING_RUNNING,
            value: NumericHealthValue(numericValue: 2500),
            unit: HealthDataUnit.METER,
            dateFrom: DateTime(2026, 9, 25, 7, 5),
            dateTo: DateTime(2026, 9, 25, 7, 25),
          ),
          _point(
            uuid: 'dist-workout-2',
            type: HealthDataType.DISTANCE_WALKING_RUNNING,
            value: NumericHealthValue(numericValue: 2500),
            unit: HealthDataUnit.METER,
            dateFrom: DateTime(2026, 9, 25, 7, 25),
            dateTo: DateTime(2026, 9, 25, 7, 44),
          ),
          _point(
            uuid: 'steps-workout-1',
            type: HealthDataType.STEPS,
            value: NumericHealthValue(numericValue: 5200),
            unit: HealthDataUnit.COUNT,
            dateFrom: DateTime(2026, 9, 25, 7, 0),
            dateTo: DateTime(2026, 9, 25, 7, 45),
          ),
          _point(
            uuid: 'cal-workout-1',
            type: HealthDataType.ACTIVE_ENERGY_BURNED,
            value: NumericHealthValue(numericValue: 410),
            unit: HealthDataUnit.KILOCALORIE,
            dateFrom: DateTime(2026, 9, 25, 7, 0),
            dateTo: DateTime(2026, 9, 25, 7, 45),
          ),
          // Explicitly linked via workoutUuid even slightly outside window:
          _point(
            uuid: 'flights-workout-1',
            type: HealthDataType.FLIGHTS_CLIMBED,
            value: NumericHealthValue(numericValue: 6),
            unit: HealthDataUnit.COUNT,
            dateFrom: DateTime(2026, 9, 25, 7, 46),
            dateTo: DateTime(2026, 9, 25, 7, 47),
            metadata: const {'workoutUuid': 'workout-run-1'},
          ),
          // Basal energy during workout window without workoutUuid should still aggregate daily:
          _point(
            uuid: 'basal-1',
            type: HealthDataType.BASAL_ENERGY_BURNED,
            value: NumericHealthValue(numericValue: 65),
            unit: HealthDataUnit.KILOCALORIE,
            dateFrom: DateTime(2026, 9, 25, 7, 10),
            dateTo: DateTime(2026, 9, 25, 7, 40),
          ),
          // Outside workout (afternoon walk without workout session):
          _point(
            uuid: 'dist-daily-1',
            type: HealthDataType.DISTANCE_WALKING_RUNNING,
            value: NumericHealthValue(numericValue: 1200),
            unit: HealthDataUnit.METER,
            dateFrom: DateTime(2026, 9, 25, 13, 0),
            dateTo: DateTime(2026, 9, 25, 13, 20),
          ),
          _point(
            uuid: 'dist-daily-2',
            type: HealthDataType.DISTANCE_WALKING_RUNNING,
            value: NumericHealthValue(numericValue: 800),
            unit: HealthDataUnit.METER,
            dateFrom: DateTime(2026, 9, 25, 17, 0),
            dateTo: DateTime(2026, 9, 25, 17, 15),
          ),
          _point(
            uuid: 'steps-daily-1',
            type: HealthDataType.STEPS,
            value: NumericHealthValue(numericValue: 3100),
            unit: HealthDataUnit.COUNT,
            dateFrom: DateTime(2026, 9, 25, 13, 0),
            dateTo: DateTime(2026, 9, 25, 17, 30),
          ),
          _point(
            uuid: 'cal-daily-1',
            type: HealthDataType.ACTIVE_ENERGY_BURNED,
            value: NumericHealthValue(numericValue: 185),
            unit: HealthDataUnit.KILOCALORIE,
            dateFrom: DateTime(2026, 9, 25, 13, 0),
            dateTo: DateTime(2026, 9, 25, 17, 30),
          ),
          _point(
            uuid: 'flights-daily-1',
            type: HealthDataType.FLIGHTS_CLIMBED,
            value: NumericHealthValue(numericValue: 4),
            unit: HealthDataUnit.COUNT,
            dateFrom: DateTime(2026, 9, 25, 14, 0),
            dateTo: DateTime(2026, 9, 25, 14, 5),
          ),
        ];

        final result = aggregator.aggregate(
          workouts: [workout],
          activityPoints: activityPoints,
          fallbackSource: 'Apple Health',
        );

        // 1. Verify workout record has aggregated distance, calories, steps, and flights climbed
        expect(result.workoutRecords, hasLength(1));
        final workoutRecord = result.workoutRecords.first;
        expect(workoutRecord.name, 'Workout');
        expect(workoutRecord.status, 'Workout (aggregated)');
        expect(workoutRecord.value, contains('running'));
        expect(workoutRecord.value, contains('410 kcal'));
        expect(workoutRecord.value, contains('5000 m'));
        expect(workoutRecord.value, contains('5200 steps'));
        expect(workoutRecord.value, contains('6 flights'));
        expect(workoutRecord.sourceData?['aggregatedWorkoutMetrics'], {
          'distanceMeters': 5000.0,
          'distanceSampleCount': 2,
          'caloriesKcal': 410.0,
          'calorieSampleCount': 1,
          'steps': 5200,
          'stepSampleCount': 1,
          'flightsClimbed': 6,
          'flightsSampleCount': 1,
        });

        // 2. Verify non-workout samples aggregated into daily records (excluding workout samples)
        final dailyById = {for (final r in result.dailyRecords) r.id: r};
        expect(
          dailyById['health:distance_walking_running:daily:2026-09-25']?.value,
          '2000',
        );
        expect(
          dailyById['health:distance_walking_running:daily:2026-09-25']?.unit,
          'm',
        );
        expect(dailyById['health:steps:daily:2026-09-25']?.value, '3100');
        expect(
          dailyById['health:active_energy_burned:daily:2026-09-25']?.value,
          '185',
        );
        expect(
          dailyById['health:basal_energy_burned:daily:2026-09-25']?.value,
          '65',
        );
        expect(
          dailyById['health:flights_climbed:daily:2026-09-25']?.value,
          '4',
        );

        // 3. Verify rawSampleCount and countRawSamples preserve true underlying sample counts
        // Workout (1) + 5 workout child samples = 6
        expect(workoutRecord.rawSampleCount, 6);
        // 5 daily records representing 6 unassociated samples (2 distance + 1 steps + 1 active cal + 1 basal cal + 1 flights)
        expect(countRawSamples(result.dailyRecords), 6);
        final allRecords = [...result.workoutRecords, ...result.dailyRecords];
        expect(allRecords, hasLength(6));
        expect(countRawSamples(allRecords), 12);
      },
    );

    testWidgets(
      'OverviewPage and CountPill display both stored aggregate count and raw sample count',
      (tester) async {
        final records = <HealthRecord>[
          HealthRecord(
            id: 'health:steps:daily:2026-09-25',
            name: 'Steps',
            value: '8500',
            unit: 'count',
            recordedAt: DateTime.utc(2026, 9, 25, 12),
            category: RecordCategory.activity,
            source: 'Apple Health',
            status: 'Daily total (aggregated)',
            sourceData: const {'sampleCount': 14},
          ),
          HealthRecord(
            id: 'health:workout:1',
            name: 'Workout',
            value: 'running · 410 kcal · 5000 m',
            unit: '',
            recordedAt: DateTime.utc(2026, 9, 25, 7),
            category: RecordCategory.activity,
            source: 'Apple Health',
            status: 'Workout (aggregated)',
            sourceData: const {
              'aggregatedWorkoutMetrics': {
                'distanceSampleCount': 3,
                'calorieSampleCount': 2,
              },
            },
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  const CountPill(count: 2, rawCount: 20),
                  Expanded(
                    child: OverviewPage(
                      records: records,
                      loading: false,
                      error: null,
                      onConnect: () {},
                      onSeeAll: () {},
                      onRetry: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('2 imported (20 raw)'), findsOneWidget);
        expect(
          find.text('2 records saved (20 raw samples)  ·  0 lab results'),
          findsOneWidget,
        );
      },
    );
  });
}

HealthDataPoint _point({
  required String uuid,
  required HealthDataType type,
  required HealthValue value,
  HealthDataUnit unit = HealthDataUnit.NO_UNIT,
  required DateTime dateFrom,
  required DateTime dateTo,
  Map<String, dynamic>? metadata,
}) {
  return HealthDataPoint(
    uuid: uuid,
    value: value,
    type: type,
    unit: unit,
    dateFrom: dateFrom,
    dateTo: dateTo,
    sourcePlatform: HealthPlatformType.appleHealth,
    sourceDeviceId: 'device-1',
    sourceId: 'source-1',
    sourceName: 'Apple Watch',
    metadata: metadata,
  );
}
