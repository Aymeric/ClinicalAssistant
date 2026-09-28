import '../models/health_record.dart';

class MeasurementSignalSummary {
  const MeasurementSignalSummary({
    required this.newLabResults,
    required this.newMeasurements,
    required this.trendCount,
    required this.patternCount,
  });

  final int newLabResults;
  final int newMeasurements;
  final int trendCount;
  final int patternCount;
}

class MeasurementSignalAnalyzer {
  const MeasurementSignalAnalyzer();

  MeasurementSignalSummary analyzeImport({
    required List<HealthRecord> newlyImported,
    required List<HealthRecord> allRecords,
    required int trendThresholdPercent,
  }) {
    final newIds = newlyImported.map((record) => record.id).toSet();
    final series = <(RecordCategory, String, String, String), List<_Reading>>{};
    for (final record in allRecords) {
      final value = parseHealthRecordValue(record.value);
      if (value == null) continue;
      final key = (
        record.category,
        record.name.trim().toLowerCase(),
        record.unit.trim().toLowerCase(),
        record.source.trim().toLowerCase(),
      );
      series.putIfAbsent(key, () => []).add(_Reading(record, value));
    }

    var trendCount = 0;
    var patternCount = 0;
    for (final readings in series.values) {
      readings.sort((a, b) {
        final byDate = a.record.recordedAt.compareTo(b.record.recordedAt);
        return byDate != 0 ? byDate : a.record.id.compareTo(b.record.id);
      });
      if (readings.length < 2) continue;

      final latest = readings.last;
      final previous = readings[readings.length - 2];
      if (!newIds.contains(latest.record.id) ||
          !latest.record.recordedAt.isAfter(previous.record.recordedAt)) {
        continue;
      }

      if (previous.value != 0) {
        final changePercent =
            ((latest.value - previous.value).abs() / previous.value.abs()) *
            100;
        if (changePercent >= trendThresholdPercent) trendCount++;
      }

      if (readings.length >= 3) {
        final earlier = readings[readings.length - 3];
        final rising =
            earlier.value < previous.value && previous.value < latest.value;
        final falling =
            earlier.value > previous.value && previous.value > latest.value;
        if (rising || falling) patternCount++;
      }
    }

    return MeasurementSignalSummary(
      newLabResults: newlyImported
          .where((record) => record.category == RecordCategory.lab)
          .length,
      newMeasurements: newlyImported
          .where((record) => record.category != RecordCategory.lab)
          .length,
      trendCount: trendCount,
      patternCount: patternCount,
    );
  }
}

class _Reading {
  const _Reading(this.record, this.value);

  final HealthRecord record;
  final double value;
}
