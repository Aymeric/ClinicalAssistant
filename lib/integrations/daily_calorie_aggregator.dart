import 'package:health/health.dart';

import '../models/health_record.dart';
import 'health_data_record_mapper.dart';

class DailyCalorieSample {
  const DailyCalorieSample({
    required this.recordedAt,
    required this.calories,
    required this.type,
  });

  final DateTime recordedAt;
  final num calories;
  final HealthDataType type;
}

class DailyCalorieAggregator {
  const DailyCalorieAggregator();

  List<HealthRecord> aggregate(
    Iterable<DailyCalorieSample> samples, {
    required HealthDataType type,
    required String source,
  }) {
    final totals = <DateTime, _DailyCalorieTotal>{};
    for (final sample in samples) {
      final localRecordedAt = sample.recordedAt.toLocal();
      final day = DateTime(
        localRecordedAt.year,
        localRecordedAt.month,
        localRecordedAt.day,
      );
      final current = totals[day];
      if (current == null) {
        totals[day] = _DailyCalorieTotal(sample.calories.toDouble(), 1);
      } else {
        totals[day] = _DailyCalorieTotal(
          current.calories + sample.calories,
          current.sampleCount + 1,
        );
      }
    }

    final days = totals.keys.toList()..sort();
    final typeLabel = HealthDataRecordMapper.labelFor(type);
    final typeCode = type.name;

    return [
      for (final day in days)
        HealthRecord(
          id: 'health:${typeCode.toLowerCase()}:daily:${_dateKey(day)}',
          name: typeLabel,
          value: formatSensibleNumber(totals[day]!.calories),
          unit: 'kcal',
          recordedAt: DateTime(day.year, day.month, day.day, 12).toUtc(),
          category: RecordCategory.activity,
          source: source,
          sourceId: 'daily-total',
          code: typeCode,
          status: 'Daily total (aggregated)',
          sourceData: {
            'aggregation': 'daily-total',
            'type': typeCode,
            'sampleCount': totals[day]!.sampleCount,
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
        byId[record.id] = existing.copyWith(
          value: formatSensibleNumber(val1 + val2),
          sourceData: {...?existing.sourceData, 'sampleCount': count1 + count2},
        );
      }
    }
    return byId.values.toList();
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _DailyCalorieTotal {
  const _DailyCalorieTotal(this.calories, this.sampleCount);

  final double calories;
  final int sampleCount;
}
