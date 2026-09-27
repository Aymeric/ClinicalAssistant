import 'package:clinical_assistant/integrations/daily_step_aggregator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const aggregator = DailyStepAggregator();

  test('combines step samples into one dated record per day', () {
    final records = aggregator.aggregate([
      DailyStepSample(recordedAt: DateTime(2026, 9, 25, 8), steps: 1200),
      DailyStepSample(recordedAt: DateTime(2026, 9, 25, 19), steps: 2300),
      DailyStepSample(recordedAt: DateTime(2026, 9, 26, 9), steps: 800),
    ], source: 'Apple Health');

    expect(records, hasLength(2));
    expect(records.first.id, 'health:steps:daily:2026-09-25');
    expect(records.first.name, 'Steps');
    expect(records.first.value, '3500');
    expect(records.first.unit, 'count');
    expect(records.first.category.name, 'activity');
    expect(records.first.source, 'Apple Health');
    expect(records.first.status, 'Daily total (aggregated)');
    expect(records.first.sourceData, {
      'aggregation': 'daily-total',
      'sampleCount': 2,
    });
    expect(records.last.value, '800');
  });
}
