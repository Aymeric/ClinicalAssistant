import 'package:health/health.dart';

import '../models/health_record.dart';

class HealthDataRecordMapper {
  const HealthDataRecordMapper();

  HealthRecord mapPoint(
    HealthDataPoint point, {
    required String fallbackSource,
  }) {
    final value = point.value.toJson();
    final source =
        point.sourceName.trim().isEmpty ? fallbackSource : point.sourceName;
    return HealthRecord(
      id: 'health:${point.sourceId}:${point.uuid}',
      name: _labelFor(point.type),
      value: _displayValue(point, value),
      unit: _unitLabel(point.unit),
      recordedAt: point.dateTo.toUtc(),
      category: _categoryFor(point.type),
      source: source,
      sourceId: point.sourceId,
      code: point.type.name,
      status: _statusFor(point),
      sourceData: point.toJson().cast<String, Object?>(),
    );
  }

  String _statusFor(HealthDataPoint point) =>
      point.type == HealthDataType.WORKOUT_ROUTE &&
              point.metadata?['route_requires_consent'] == true
          ? 'Consent required'
          : 'Imported';

  RecordCategory _categoryFor(HealthDataType type) => switch (type) {
        HealthDataType.SLEEP_ASLEEP ||
        HealthDataType.SLEEP_AWAKE ||
        HealthDataType.SLEEP_DEEP ||
        HealthDataType.SLEEP_LIGHT ||
        HealthDataType.SLEEP_REM =>
          RecordCategory.sleep,
        HealthDataType.NUTRITION ||
        HealthDataType.WATER =>
          RecordCategory.nutrition,
        HealthDataType.MENSTRUATION_FLOW => RecordCategory.cycleTracking,
        HealthDataType.ACTIVE_ENERGY_BURNED ||
        HealthDataType.BASAL_ENERGY_BURNED ||
        HealthDataType.FLIGHTS_CLIMBED ||
        HealthDataType.STEPS ||
        HealthDataType.TOTAL_CALORIES_BURNED ||
        HealthDataType.WORKOUT ||
        HealthDataType.WORKOUT_ROUTE =>
          RecordCategory.activity,
        _ => RecordCategory.vital,
      };

  String _displayValue(HealthDataPoint point, Map<String, dynamic> json) {
    final numericValue = json['numericValue'];
    if (numericValue is num) return _formatNumber(numericValue);

    return switch (point.value) {
      WorkoutHealthValue value => _workoutSummary(value),
      WorkoutRouteHealthValue value => _workoutRouteSummary(
          value,
          consentRequired: point.metadata?['route_requires_consent'] == true,
        ),
      NutritionHealthValue value => _nutritionSummary(value),
      MenstruationFlowHealthValue value => _menstruationSummary(value),
      _ => point.value.toString(),
    };
  }

  String _workoutRouteSummary(
    WorkoutRouteHealthValue value, {
    required bool consentRequired,
  }) {
    if (consentRequired) return 'Consent required to read this route';
    final count = value.locations.length;
    final sampleLabel = count == 1 ? 'sample' : 'samples';
    return 'Workout route · $count location $sampleLabel';
  }

  String _workoutSummary(WorkoutHealthValue value) {
    final details = <String>[
      value.workoutActivityType.name.replaceAll('_', ' ').toLowerCase(),
    ];
    if (value.totalEnergyBurned != null) {
      details.add(
        '${formatSensibleNumber(value.totalEnergyBurned!)} ${_unitLabel(value.totalEnergyBurnedUnit ?? HealthDataUnit.KILOCALORIE)}',
      );
    }
    if (value.totalDistance != null) {
      details.add(
        '${formatSensibleNumber(value.totalDistance!)} ${_unitLabel(value.totalDistanceUnit ?? HealthDataUnit.METER)}',
      );
    }
    if (value.totalSteps != null) {
      details.add('${formatSensibleNumber(value.totalSteps!)} steps');
    }
    return details.join(' · ');
  }

  String _nutritionSummary(NutritionHealthValue value) {
    final details = <String>[
      if (value.mealType case final mealType?)
        mealType.replaceAll('_', ' ').toLowerCase(),
      if (value.name case final name? when name.trim().isNotEmpty) name.trim(),
      if (value.calories case final calories?)
        '${_formatNumber(calories)} kcal',
      if (value.protein case final protein?)
        '${_formatNumber(protein)} g protein',
      if (value.carbs case final carbs?) '${_formatNumber(carbs)} g carbs',
      if (value.fat case final fat?) '${_formatNumber(fat)} g fat',
    ];
    return details.isEmpty ? 'Nutrition entry' : details.join(' · ');
  }

  String _menstruationSummary(MenstruationFlowHealthValue value) {
    final details = <String>[
      value.flow?.name.replaceAll('_', ' ').toLowerCase() ?? 'Flow recorded',
      if (value.isStartOfCycle == true) 'cycle start',
    ];
    return details.join(' · ');
  }

  String _formatNumber(num value) => formatSensibleNumber(value);

  String _labelFor(HealthDataType type) => switch (type) {
        HealthDataType.ACTIVE_ENERGY_BURNED => 'Active energy burned',
        HealthDataType.BASAL_ENERGY_BURNED => 'Basal energy burned',
        HealthDataType.BLOOD_GLUCOSE => 'Blood glucose',
        HealthDataType.BLOOD_OXYGEN => 'Blood oxygen',
        HealthDataType.BLOOD_PRESSURE_SYSTOLIC => 'Systolic blood pressure',
        HealthDataType.BLOOD_PRESSURE_DIASTOLIC => 'Diastolic blood pressure',
        HealthDataType.BODY_FAT_PERCENTAGE => 'Body fat',
        HealthDataType.BODY_MASS_INDEX => 'Body mass index',
        HealthDataType.BODY_TEMPERATURE => 'Body temperature',
        HealthDataType.FLIGHTS_CLIMBED => 'Flights climbed',
        HealthDataType.HEART_RATE => 'Heart rate',
        HealthDataType.HEIGHT => 'Height',
        HealthDataType.LEAN_BODY_MASS => 'Lean body mass',
        HealthDataType.MENSTRUATION_FLOW => 'Menstrual flow',
        HealthDataType.NUTRITION => 'Nutrition',
        HealthDataType.RESPIRATORY_RATE => 'Respiratory rate',
        HealthDataType.RESTING_HEART_RATE => 'Resting heart rate',
        HealthDataType.SLEEP_ASLEEP => 'Sleep (asleep)',
        HealthDataType.SLEEP_AWAKE => 'Sleep (awake)',
        HealthDataType.SLEEP_DEEP => 'Sleep (deep)',
        HealthDataType.SLEEP_LIGHT => 'Sleep (light)',
        HealthDataType.SLEEP_REM => 'Sleep (REM)',
        HealthDataType.STEPS => 'Steps',
        HealthDataType.TOTAL_CALORIES_BURNED => 'Total calories burned',
        HealthDataType.WATER => 'Water',
        HealthDataType.WEIGHT => 'Weight',
        HealthDataType.WORKOUT => 'Workout',
        HealthDataType.WORKOUT_ROUTE => 'Workout route',
        _ => type.name.replaceAll('_', ' ').toLowerCase(),
      };

  String _unitLabel(HealthDataUnit unit) => switch (unit) {
        HealthDataUnit.MILLIGRAM_PER_DECILITER => 'mg/dL',
        HealthDataUnit.MILLIMOLES_PER_LITER => 'mmol/L',
        HealthDataUnit.PERCENT => '%',
        HealthDataUnit.MILLIMETER_OF_MERCURY => 'mmHg',
        HealthDataUnit.DEGREE_CELSIUS => '°C',
        HealthDataUnit.DEGREE_FAHRENHEIT => '°F',
        HealthDataUnit.BEATS_PER_MINUTE => 'bpm',
        HealthDataUnit.RESPIRATIONS_PER_MINUTE => 'breaths/min',
        HealthDataUnit.MILLISECOND => 'ms',
        HealthDataUnit.METER => 'm',
        HealthDataUnit.CENTIMETER => 'cm',
        HealthDataUnit.KILOGRAM => 'kg',
        HealthDataUnit.POUND => 'lb',
        HealthDataUnit.KILOCALORIE => 'kcal',
        HealthDataUnit.LITER => 'L',
        HealthDataUnit.MILLILITER => 'mL',
        HealthDataUnit.GRAM => 'g',
        HealthDataUnit.MINUTE => 'min',
        HealthDataUnit.COUNT => 'count',
        HealthDataUnit.NO_UNIT => '',
        HealthDataUnit.UNKNOWN_UNIT => 'Unknown unit',
        _ => unit.name.replaceAll('_', ' ').toLowerCase(),
      };
}
