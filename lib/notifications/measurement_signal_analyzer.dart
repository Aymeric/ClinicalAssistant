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

typedef _SeriesKey = (RecordCategory, String, String, String);

_SeriesKey _seriesKey(HealthRecord record) => (
  record.category,
  record.name.trim().toLowerCase(),
  record.unit.trim().toLowerCase(),
  record.source.trim().toLowerCase(),
);

class MeasurementSignalAnalyzer {
  const MeasurementSignalAnalyzer();

  MeasurementSignalSummary analyzeImport({
    required List<HealthRecord> newlyImported,
    required List<HealthRecord> allRecords,
    required int trendThresholdPercent,
  }) {
    if (newlyImported.isEmpty) {
      return const MeasurementSignalSummary(
        newLabResults: 0,
        newMeasurements: 0,
        trendCount: 0,
        patternCount: 0,
      );
    }

    // Single pass over newlyImported to calculate category counts and identify
    // candidate metric series keys. Series not present in newlyImported cannot
    // trigger trend or pattern signals, so filtering allRecords by relevantKeys
    // eliminates non-matching numeric parsing, heap allocations, and sorting.
    var newLabResults = 0;
    var newMeasurements = 0;
    final newIds = <String>{};
    final relevantKeys = <_SeriesKey>{};

    for (final record in newlyImported) {
      if (record.category == RecordCategory.lab) {
        newLabResults++;
      } else {
        newMeasurements++;
      }
      newIds.add(record.id);
      if (parseHealthRecordValue(record.value) != null) {
        relevantKeys.add(_seriesKey(record));
      }
    }

    var trendCount = 0;
    var patternCount = 0;

    if (relevantKeys.isNotEmpty) {
      final series = <_SeriesKey, List<_Reading>>{};

      for (final record in allRecords) {
        final key = _seriesKey(record);
        if (!relevantKeys.contains(key)) continue;

        final value = parseHealthRecordValue(record.value);
        if (value == null) continue;

        series.putIfAbsent(key, () => []).add(_Reading(record, value));
      }

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
    }

    return MeasurementSignalSummary(
      newLabResults: newLabResults,
      newMeasurements: newMeasurements,
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
