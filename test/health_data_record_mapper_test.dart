import 'dart:convert';

import 'package:clinical_assistant/integrations/health_data_record_mapper.dart';
import 'package:clinical_assistant/integrations/health_platform_importer.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:health/health.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = HealthDataRecordMapper();

  test('requests the complete shared set of platform health types', () {
    expect(HealthPlatformImporter.sharedDataTypes, hasLength(28));
    expect(HealthPlatformImporter.sharedDataTypes.toSet(), {
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
    });
  });

  test(
    'excludes TOTAL_CALORIES_BURNED on iOS due to Apple HealthKit incompatibility',
    () {
      final importer = HealthPlatformImporter();
      expect(
        importer.isDataTypeAvailable(
          HealthDataType.TOTAL_CALORIES_BURNED,
          isIos: true,
        ),
        isFalse,
      );
      expect(
        importer.isDataTypeAvailable(
          HealthDataType.TOTAL_CALORIES_BURNED,
          isIos: false,
        ),
        isTrue,
      );
      expect(
        importer.isDataTypeAvailable(
          HealthDataType.ACTIVE_ENERGY_BURNED,
          isIos: true,
        ),
        isTrue,
      );
    },
  );

  test('maps sleep durations into their own category', () {
    final record = mapper.mapPoint(
      _point(
        HealthDataType.SLEEP_DEEP,
        NumericHealthValue(numericValue: 90),
        unit: HealthDataUnit.MINUTE,
        dateTo: DateTime.utc(2026, 1, 1, 1, 30),
      ),
      fallbackSource: 'Apple Health',
    );

    expect(record.category, RecordCategory.sleep);
    expect(record.name, 'Sleep (deep)');
    expect(record.displayValue, '90 min');
    expect(record.sourceData?['type'], 'SLEEP_DEEP');
  });

  test('summarizes nutrition while preserving all nutrient fields', () {
    final record = mapper.mapPoint(
      _point(
        HealthDataType.NUTRITION,
        NutritionHealthValue(
          name: 'Oatmeal',
          mealType: 'BREAKFAST',
          calories: 350,
          protein: 12,
          carbs: 45,
          fat: 8.5,
          fatSaturated: 1.1,
          sodium: 0.2,
        ),
      ),
      fallbackSource: 'Health Connect',
    );

    expect(record.category, RecordCategory.nutrition);
    expect(
      record.value,
      'breakfast · Oatmeal · 350 kcal · 12 g protein · 45 g carbs · 8.5 g fat',
    );
    final rawValue = jsonEncode(record.sourceData?['value']);
    expect(rawValue, contains('sodium'));
    expect(rawValue, contains('fat_saturated'));
  });

  test('maps workouts and retains route coordinates and timestamps', () {
    final workout = mapper.mapPoint(
      _point(
        HealthDataType.WORKOUT,
        WorkoutHealthValue(
          workoutActivityType: HealthWorkoutActivityType.RUNNING,
          totalEnergyBurned: 420,
          totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
          totalDistance: 5000,
          totalDistanceUnit: HealthDataUnit.METER,
          totalSteps: 6200,
          totalStepsUnit: HealthDataUnit.COUNT,
        ),
      ),
      fallbackSource: 'Health Connect',
    );
    final route = mapper.mapPoint(
      _point(
        HealthDataType.WORKOUT_ROUTE,
        WorkoutRouteHealthValue(
          workoutUuid: 'workout-1',
          locations: [
            WorkoutRouteLocation(
              latitude: 37.3317,
              longitude: -122.0301,
              timestamp: DateTime.utc(2026, 1, 1, 8),
              altitude: 12,
            ),
          ],
        ),
      ),
      fallbackSource: 'Health Connect',
    );

    expect(workout.category, RecordCategory.activity);
    expect(workout.value, 'running · 420 kcal · 5000 m · 6200 steps');
    expect(route.category, RecordCategory.activity);
    expect(route.value, 'Workout route · 1 location sample');
    final routeData = jsonEncode(route.sourceData?['value']);
    expect(routeData, contains('locations'));
    expect(routeData, contains('37.3317'));
    expect(routeData, contains('2026-01-01T08:00:00.000Z'));
  });

  test('identifies workout routes that require Health Connect consent', () {
    final record = mapper.mapPoint(
      _point(
        HealthDataType.WORKOUT_ROUTE,
        WorkoutRouteHealthValue(locations: [], workoutUuid: 'workout-1'),
        metadata: const {'route_requires_consent': true},
      ),
      fallbackSource: 'Health Connect',
    );

    expect(record.value, 'Consent required to read this route');
    expect(record.status, 'Consent required');
    expect(
      record.sourceData?['metadata'],
      containsPair('route_requires_consent', true),
    );
  });

  test('maps menstrual-flow entries to cycle tracking', () {
    final record = mapper.mapPoint(
      _point(
        HealthDataType.MENSTRUATION_FLOW,
        MenstruationFlowHealthValue(
          flow: MenstrualFlow.medium,
          dateTime: DateTime.utc(2026, 1, 1),
          isStartOfCycle: true,
          wasUserEntered: true,
        ),
      ),
      fallbackSource: 'Apple Health',
    );

    expect(record.category, RecordCategory.cycleTracking);
    expect(record.value, 'medium · cycle start');
    expect(jsonEncode(record.sourceData?['value']), contains('wasUserEntered'));
  });

  test('uses a fallback source when the platform point has no source name', () {
    final record = mapper.mapPoint(
      _point(
        HealthDataType.HEART_RATE,
        NumericHealthValue(numericValue: 72),
        unit: HealthDataUnit.BEATS_PER_MINUTE,
        sourceName: ' ',
      ),
      fallbackSource: 'Health Connect',
    );

    expect(record.category, RecordCategory.vital);
    expect(record.source, 'Health Connect');
    expect(record.displayValue, '72 bpm');
  });
}

HealthDataPoint _point(
  HealthDataType type,
  HealthValue value, {
  HealthDataUnit unit = HealthDataUnit.NO_UNIT,
  DateTime? dateFrom,
  DateTime? dateTo,
  String sourceName = 'Test health source',
  Map<String, dynamic>? metadata,
}) {
  final start = dateFrom ?? DateTime.utc(2026, 1, 1);
  return HealthDataPoint(
    uuid: 'point-1',
    value: value,
    type: type,
    unit: unit,
    dateFrom: start,
    dateTo: dateTo ?? start,
    sourcePlatform: HealthPlatformType.googleHealthConnect,
    sourceDeviceId: 'device-1',
    sourceId: 'source-1',
    sourceName: sourceName,
    metadata: metadata,
  );
}
