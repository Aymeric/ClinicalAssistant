import '../models/health_record.dart';

class DailyStepSample {
  const DailyStepSample({required this.recordedAt, required this.steps});

  final DateTime recordedAt;
  final num steps;
}

class DailyStepAggregator {
  const DailyStepAggregator();

  List<HealthRecord> aggregate(
    Iterable<DailyStepSample> samples, {
    required String source,
  }) {
    final totals = <DateTime, _DailyStepTotal>{};
    for (final sample in samples) {
      final localRecordedAt = sample.recordedAt.toLocal();
      final day = DateTime(
        localRecordedAt.year,
        localRecordedAt.month,
        localRecordedAt.day,
      );
      final current = totals[day];
      if (current == null) {
        totals[day] = _DailyStepTotal(sample.steps, 1);
      } else {
        totals[day] = _DailyStepTotal(
          current.steps + sample.steps,
          current.sampleCount + 1,
        );
      }
    }

    final days = totals.keys.toList()..sort();
    return [
      for (final day in days)
        HealthRecord(
          id: 'health:steps:daily:${_dateKey(day)}',
          name: 'Steps',
          value: totals[day]!.steps.round().toString(),
          unit: 'count',
          recordedAt: DateTime(day.year, day.month, day.day, 12).toUtc(),
          category: RecordCategory.activity,
          source: source,
          sourceId: 'daily-total',
          code: 'STEPS',
          status: 'Daily total (aggregated)',
          sourceData: {
            'aggregation': 'daily-total',
            'sampleCount': totals[day]!.sampleCount,
          },
        ),
    ];
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _DailyStepTotal {
  const _DailyStepTotal(this.steps, this.sampleCount);

  final num steps;
  final int sampleCount;
}
