import 'package:health/health.dart';

import '../models/health_record.dart';
import 'health_data_record_mapper.dart';

class DailyDistanceSample {
  const DailyDistanceSample({
    required this.recordedAt,
    required this.distanceMeters,
    required this.type,
  });

  final DateTime recordedAt;
  final num distanceMeters;
  final HealthDataType type;
}

class DailyDistanceAggregator {
  const DailyDistanceAggregator();

  /// Converts a distance [value] in [unit] to meters (`m`).
  static double toMeters(num value, HealthDataUnit unit) {
    return switch (unit) {
      HealthDataUnit.CENTIMETER => value.toDouble() / 100.0,
      HealthDataUnit.METER => value.toDouble(),
      _ when unit.name == 'KILOMETER' => value.toDouble() * 1000.0,
      _ when unit.name == 'MILE' => value.toDouble() * 1609.344,
      _ => value.toDouble(),
    };
  }

  List<HealthRecord> aggregate(
    Iterable<DailyDistanceSample> samples, {
    required HealthDataType type,
    required String source,
  }) {
    final totals = <DateTime, _DailyDistanceTotal>{};
    for (final sample in samples) {
      final localRecordedAt = sample.recordedAt.toLocal();
      final day = DateTime(
        localRecordedAt.year,
        localRecordedAt.month,
        localRecordedAt.day,
      );
      final current = totals[day];
      if (current == null) {
        totals[day] = _DailyDistanceTotal(sample.distanceMeters.toDouble(), 1);
      } else {
        totals[day] = _DailyDistanceTotal(
          current.distanceMeters + sample.distanceMeters.toDouble(),
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
          value: formatSensibleNumber(totals[day]!.distanceMeters),
          unit: 'm',
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

class _DailyDistanceTotal {
  const _DailyDistanceTotal(this.distanceMeters, this.sampleCount);

  final double distanceMeters;
  final int sampleCount;
}
