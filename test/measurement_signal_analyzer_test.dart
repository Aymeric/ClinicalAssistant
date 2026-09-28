import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/notifications/measurement_signal_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const analyzer = MeasurementSignalAnalyzer();

  test('finds threshold changes and three-reading directional patterns', () {
    final first = _reading('first', '100', DateTime.utc(2026, 1, 1));
    final second = _reading('second', '110', DateTime.utc(2026, 1, 2));
    final latest = _reading('latest', '121', DateTime.utc(2026, 1, 3));

    final summary = analyzer.analyzeImport(
      newlyImported: [latest],
      allRecords: [latest, first, second],
      trendThresholdPercent: 10,
    );

    expect(summary.newMeasurements, 1);
    expect(summary.newLabResults, 0);
    expect(summary.trendCount, 1);
    expect(summary.patternCount, 1);
  });

  test('does not signal old, duplicate, zero-baseline, or nonnumeric data', () {
    final existing = _reading('existing', '100', DateTime.utc(2026, 1, 2));
    final oldImport = _reading('old-import', '120', DateTime.utc(2026, 1, 1));
    final zero = _reading(
      'zero',
      '0',
      DateTime.utc(2026, 1, 1),
      name: 'Steps',
      unit: 'count',
      category: RecordCategory.activity,
    );
    final nonnumeric = _reading(
      'nonnumeric',
      'below detection',
      DateTime.utc(2026, 1, 2),
      name: 'Qualitative result',
      category: RecordCategory.lab,
    );

    final oldSummary = analyzer.analyzeImport(
      newlyImported: [oldImport],
      allRecords: [oldImport, existing],
      trendThresholdPercent: 5,
    );
    final zeroSummary = analyzer.analyzeImport(
      newlyImported: [
        _reading(
          'zero-latest',
          '10',
          DateTime.utc(2026, 1, 2),
          name: 'Steps',
          unit: 'count',
          category: RecordCategory.activity,
        ),
      ],
      allRecords: [
        zero,
        _reading(
          'zero-latest',
          '10',
          DateTime.utc(2026, 1, 2),
          name: 'Steps',
          unit: 'count',
          category: RecordCategory.activity,
        ),
      ],
      trendThresholdPercent: 5,
    );
    final nonnumericSummary = analyzer.analyzeImport(
      newlyImported: [nonnumeric],
      allRecords: [nonnumeric],
      trendThresholdPercent: 5,
    );
    final duplicateSummary = analyzer.analyzeImport(
      newlyImported: const [],
      allRecords: [existing],
      trendThresholdPercent: 5,
    );

    expect(oldSummary.trendCount, 0);
    expect(oldSummary.patternCount, 0);
    expect(zeroSummary.trendCount, 0);
    expect(nonnumericSummary.trendCount, 0);
    expect(nonnumericSummary.patternCount, 0);
    expect(duplicateSummary.newLabResults, 0);
    expect(duplicateSummary.newMeasurements, 0);
  });

  test('does not compare readings from different sources', () {
    final previous = _reading(
      'previous',
      '100',
      DateTime.utc(2026, 1, 1),
      source: 'Health Connect',
    );
    final latest = _reading(
      'latest',
      '140',
      DateTime.utc(2026, 1, 2),
      source: 'Apple Health',
    );

    final summary = analyzer.analyzeImport(
      newlyImported: [latest],
      allRecords: [previous, latest],
      trendThresholdPercent: 5,
    );

    expect(summary.trendCount, 0);
    expect(summary.patternCount, 0);
  });
}

HealthRecord _reading(
  String id,
  String value,
  DateTime recordedAt, {
  String name = 'Heart rate',
  String unit = 'bpm',
  String source = 'Health Connect',
  RecordCategory category = RecordCategory.vital,
}) {
  return HealthRecord(
    id: id,
    name: name,
    value: value,
    unit: unit,
    recordedAt: recordedAt,
    category: category,
    source: source,
  );
}
