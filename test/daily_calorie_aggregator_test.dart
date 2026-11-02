import 'package:clinical_assistant/integrations/daily_calorie_aggregator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

void main() {
  const aggregator = DailyCalorieAggregator();

  test('combines calorie samples into one dated record per day per type', () {
    final records = aggregator.aggregate(
      [
        DailyCalorieSample(
          recordedAt: DateTime(2026, 9, 25, 8, 30),
          calories: 120.5,
          type: HealthDataType.TOTAL_CALORIES_BURNED,
        ),
        DailyCalorieSample(
          recordedAt: DateTime(2026, 9, 25, 18, 45),
          calories: 340.5,
          type: HealthDataType.TOTAL_CALORIES_BURNED,
        ),
        DailyCalorieSample(
          recordedAt: DateTime(2026, 9, 26, 12),
          calories: 500,
          type: HealthDataType.TOTAL_CALORIES_BURNED,
        ),
      ],
      type: HealthDataType.TOTAL_CALORIES_BURNED,
      source: 'Health Connect',
    );

    expect(records, hasLength(2));
    expect(records.first.id, 'health:total_calories_burned:daily:2026-09-25');
    expect(records.first.name, 'Total calories burned');
    expect(records.first.value, '461');
    expect(records.first.unit, 'kcal');
    expect(records.first.category.name, 'activity');
    expect(records.first.source, 'Health Connect');
    expect(records.first.status, 'Daily total (aggregated)');
    expect(records.first.sourceData, {
      'aggregation': 'daily-total',
      'type': 'TOTAL_CALORIES_BURNED',
      'sampleCount': 2,
    });
    expect(records.last.value, '500');
  });

  test(
    'combineDailyRecords merges multiple daily records sharing the same ID',
    () {
      final batch1 = aggregator.aggregate(
        [
          DailyCalorieSample(
            recordedAt: DateTime(2026, 9, 25, 8, 30),
            calories: 100,
            type: HealthDataType.TOTAL_CALORIES_BURNED,
          ),
        ],
        type: HealthDataType.TOTAL_CALORIES_BURNED,
        source: 'Health Connect',
      );
      final batch2 = aggregator.aggregate(
        [
          DailyCalorieSample(
            recordedAt: DateTime(2026, 9, 25, 18, 0),
            calories: 250,
            type: HealthDataType.TOTAL_CALORIES_BURNED,
          ),
        ],
        type: HealthDataType.TOTAL_CALORIES_BURNED,
        source: 'Health Connect',
      );

      final combined = DailyCalorieAggregator.combineDailyRecords([
        ...batch1,
        ...batch2,
      ]);

      expect(combined, hasLength(1));
      expect(
        combined.first.id,
        'health:total_calories_burned:daily:2026-09-25',
      );
      expect(combined.first.value, '350');
      expect(combined.first.sourceData?['sampleCount'], 2);
    },
  );
}
