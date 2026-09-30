import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/trends/health_trend.dart';
import 'package:clinical_assistant/trends/health_trends_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('groups numeric records by category, name, and exact unit', () {
    final records = [
      _record(
        'glucose-1',
        'Blood glucose',
        '100',
        'mg/dL',
        RecordCategory.vital,
      ),
      _record(
        'glucose-2',
        'blood glucose',
        '105',
        'mg/dL',
        RecordCategory.vital,
      ),
      _record(
        'glucose-mmol',
        'Blood glucose',
        '5.8',
        'mmol/L',
        RecordCategory.vital,
      ),
      _record('steps', 'Steps', '8,200', 'count', RecordCategory.activity),
      _record(
        'qualitative',
        'Urine glucose',
        'Negative',
        '',
        RecordCategory.lab,
      ),
      _record('infinity', 'Other', 'Infinity', '', RecordCategory.lab),
    ];

    final series = buildHealthTrendSeries(records);

    expect(series, hasLength(3));
    expect(series.map((item) => item.category).toSet(), {
      RecordCategory.vital,
      RecordCategory.activity,
    });
    expect(
      series.singleWhere((item) => item.name == 'Steps').points.single.value,
      8200,
    );
    expect(
      series
          .singleWhere(
            (item) =>
                item.name.toLowerCase() == 'blood glucose' &&
                item.unit == 'mg/dL',
          )
          .points,
      hasLength(2),
    );
  });

  test(
    'parses only numeric reference ranges matching the measurement unit',
    () {
      final closed = parseHealthReferenceRange(
        '90–110 mg/dL',
        expectedUnit: 'mg/dL',
      );
      final upperOnly = parseHealthReferenceRange(
        '—–5.2 mmol/L',
        expectedUnit: 'mmol/L',
      );
      final lowerThreshold = parseHealthReferenceRange(
        '>= 3.5 mmol/L',
        expectedUnit: 'mmol/L',
      );

      expect(closed?.lowerBound, 90);
      expect(closed?.upperBound, 110);
      expect(upperOnly?.lowerBound, isNull);
      expect(upperOnly?.upperBound, 5.2);
      expect(lowerThreshold?.lowerBound, 3.5);
      expect(lowerThreshold?.upperBound, isNull);
      expect(
        parseHealthReferenceRange('90–110 mmol/L', expectedUnit: 'mg/dL'),
        isNull,
      );
      expect(
        parseHealthReferenceRange('90–110 mg/DL', expectedUnit: 'mg/dL'),
        isNull,
      );
      expect(
        parseHealthReferenceRange(
          'Within expected limits',
          expectedUnit: 'mg/dL',
        ),
        isNull,
      );
    },
  );

  test(
    'places reference markers only at records that supply a matching range',
    () {
      final points = [
        _point('with-range', 100, 0, referenceRange: '90–110 mg/dL'),
        _point('wrong-unit', 101, 1, referenceRange: '4.0–6.0 mmol/L'),
        _point('no-range', 102, 2),
      ];

      final markers = buildHealthTrendReferenceMarks(points, unit: 'mg/dL');

      expect(markers, hasLength(1));
      expect(markers.single.index, 0);
      expect(markers.single.range.sourceText, '90–110 mg/dL');
    },
  );

  test('summarizes the latest flagged lab against its earlier result', () {
    final records = [
      _record(
        'glucose-old',
        'Blood glucose',
        '150',
        'mg/dL',
        RecordCategory.lab,
        at: DateTime.utc(2026, 9, 1),
        referenceRange: '70–99 mg/dL',
      ),
      _record(
        'glucose-latest',
        'blood glucose',
        '120',
        'mg/dL',
        RecordCategory.lab,
        at: DateTime.utc(2026, 9, 10),
        referenceRange: '70–99 mg/dL',
      ),
      _record(
        'glucose-other-unit',
        'Blood glucose',
        '7',
        'mmol/L',
        RecordCategory.lab,
        at: DateTime.utc(2026, 9, 11),
        referenceRange: '3–6 mmol/L',
      ),
    ];

    final summaries = buildLatestLabResultSummaries(records);
    final mgSummary = summaries.singleWhere(
      (summary) => summary.latest.record.unit == 'mg/dL',
    );

    expect(summaries, hasLength(2));
    expect(mgSummary.latest.record.id, 'glucose-latest');
    expect(mgSummary.previous?.record.id, 'glucose-old');
    expect(mgSummary.latestStatus, HealthReferenceStatus.above);
    expect(mgSummary.direction, HealthLabTrendDirection.closerToRange);
  });

  test(
    'uses earlier history outside candidates and reports range transitions',
    () {
      final earlier = _record(
        'potassium-low',
        'Potassium',
        '3.1',
        'mmol/L',
        RecordCategory.lab,
        at: DateTime.utc(2026, 8, 1),
        referenceRange: '3.5–5 mmol/L',
      );
      final inRange = _record(
        'potassium-current',
        'Potassium',
        '3.8',
        'mmol/L',
        RecordCategory.lab,
        at: DateTime.utc(2026, 9, 1),
        referenceRange: '3.5–5 mmol/L',
      );

      final summary = buildLatestLabResultSummaries(
        [earlier, inRange],
        candidates: [inRange],
      ).single;

      expect(summary.latest.record.id, 'potassium-current');
      expect(summary.previous?.record.id, 'potassium-low');
      expect(summary.latestStatus, HealthReferenceStatus.within);
      expect(summary.direction, HealthLabTrendDirection.enteredRange);
      expect(
        buildLatestLabResultSummaries([earlier]).single.direction,
        HealthLabTrendDirection.unavailable,
      );
    },
  );

  test('does not retain an older numeric flag after a newer text result', () {
    final numeric = _record(
      'lab-numeric',
      'Test result',
      '150',
      'mg/dL',
      RecordCategory.lab,
      at: DateTime.utc(2026, 9, 1),
      referenceRange: '70–99 mg/dL',
    );
    final newerText = _record(
      'lab-text',
      'Test result',
      'Not detected',
      'mg/dL',
      RecordCategory.lab,
      at: DateTime.utc(2026, 9, 10),
      referenceRange: '70–99 mg/dL',
    );

    expect(buildLatestLabResultSummaries([numeric, newerText]), isEmpty);
  });

  test('calculates descriptive summary and a three-reading moving average', () {
    final points = [
      _point('first', 10, 0),
      _point('second', 15, 2),
      _point('third', 20, 1),
      _point('fourth', 20, 3),
    ];

    final summary = summarizeHealthTrend(points);

    expect(summary.latest.record.id, 'fourth');
    expect(summary.previous?.record.id, 'second');
    expect(summary.change, 5);
    expect(summary.percentChange, closeTo(33.333333, 0.001));
    expect(summary.average, 16.25);
    expect(summary.minimum, 10);
    expect(summary.maximum, 20);
    expect(movingAverageValues(points), [15, 18.333333333333332]);
    expect(movingAverageValues(points, period: 2), [12.5, 17.5, 20]);
    expect(movingAverageValues(points, period: 5), isEmpty);
  });

  test('filters by date and avoids percentage change from a zero baseline', () {
    final now = DateTime(2026, 9, 26);
    final points = [
      _point('old', 30, 0, at: now.subtract(const Duration(days: 40))),
      _point('baseline', 0, 0, at: now.subtract(const Duration(days: 2))),
      _point('latest', 5, 0, at: now),
    ];

    final recent = pointsWithinRange(points, now: now, days: 30);

    expect(recent.map((point) => point.record.id), ['baseline', 'latest']);
    expect(summarizeHealthTrend(recent).change, 5);
    expect(summarizeHealthTrend(recent).percentChange, isNull);
  });

  test('downsampling preserves narrow peaks and chronological positions', () {
    final points = [
      for (var index = 0; index < 2000; index++)
        _point('sample-$index', index == 1010 ? 1000 : 10, index),
    ];

    final indexes = sampleHealthTrendIndexes(points);

    expect(indexes, contains(1010));
    expect(indexes.first, 0);
    expect(indexes.last, 1999);
    expect(indexes.length, lessThanOrEqualTo(120));
    expect(indexes, orderedEquals([...indexes]..sort()));
  });

  testWidgets(
    'filters category and date range, and toggles the moving average',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.now();
      final records = [
        _record(
          'glucose-old',
          'Blood glucose',
          '96',
          'mg/dL',
          RecordCategory.vital,
          at: now.subtract(const Duration(days: 40)),
          referenceRange: '90–110 mg/dL',
        ),
        _record(
          'glucose-recent-1',
          'Blood glucose',
          '101',
          'mg/dL',
          RecordCategory.vital,
          at: now.subtract(const Duration(days: 20)),
          referenceRange: '90–110 mg/dL',
        ),
        _record(
          'glucose-recent-2',
          'Blood glucose',
          '104',
          'mg/dL',
          RecordCategory.vital,
          at: now.subtract(const Duration(days: 1)),
          referenceRange: '95–115 mg/dL',
        ),
        _record(
          'heart-recent-1',
          'Heart rate',
          '68',
          'bpm',
          RecordCategory.vital,
          at: now.subtract(const Duration(days: 10)),
        ),
        _record(
          'heart-recent-2',
          'Heart rate',
          '72',
          'bpm',
          RecordCategory.vital,
          at: now.subtract(const Duration(days: 1)),
        ),
        _record(
          'lab-old',
          'Hemoglobin A1c',
          '5.8',
          '%',
          RecordCategory.lab,
          at: now.subtract(const Duration(days: 60)),
        ),
        _record(
          'lab-new',
          'Hemoglobin A1c',
          '6.1',
          '%',
          RecordCategory.lab,
          at: now.subtract(const Duration(days: 2)),
        ),
        _record(
          'steps-1',
          'Steps',
          '7200',
          'count',
          RecordCategory.activity,
          at: now.subtract(const Duration(days: 2)),
        ),
        _record(
          'steps-2',
          'Steps',
          '8000',
          'count',
          RecordCategory.activity,
          at: now.subtract(const Duration(days: 1)),
        ),
        _record(
          'lab-text',
          'Urine glucose',
          'Negative',
          '',
          RecordCategory.lab,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HealthTrendsPage(records: records)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'initial compact layout');
      await tester.tap(find.byKey(const ValueKey('trend-category-vital')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'after category filter');

      expect(find.text('Blood glucose'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('trend-record-glucose-old')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('trend-range-days30')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'after range filter');
      expect(
        find.byKey(const ValueKey('trend-record-glucose-old')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('trend-record-glucose-recent-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('trend-record-glucose-recent-2')),
        findsOneWidget,
      );
      expect(find.text('Source reference ranges'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          RegExp('Shows source reference ranges for 2 readings'),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Source reference range: 95–115 mg/dL'),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('trend-measurement-picker')),
      );
      await tester.tap(find.byKey(const ValueKey('trend-measurement-picker')));
      await tester.pumpAndSettle();
      final picker = find.byKey(const ValueKey('measurement-picker-sheet'));
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isFalse,
      );
      await tester.enterText(
        find.byKey(const ValueKey('measurement-search')),
        'heart',
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: picker, matching: find.text('Heart rate')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: picker, matching: find.text('Blood glucose')),
        findsNothing,
      );
      await tester.tap(
        find.descendant(of: picker, matching: find.text('Heart rate')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Heart rate'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('trend-range-days30')),
            )
            .selected,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('trend-measurement-picker')));
      await tester.pumpAndSettle();
      final secondPicker = find.byKey(
        const ValueKey('measurement-picker-sheet'),
      );
      await tester.enterText(
        find.byKey(const ValueKey('measurement-search')),
        'glucose',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: secondPicker, matching: find.text('Blood glucose')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('trend-range-all')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'after all-time filter');
      await tester.ensureVisible(
        find.byKey(const ValueKey('trend-moving-average')),
      );
      await tester.tap(find.byKey(const ValueKey('trend-moving-average')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FilterChip>(
              find.byKey(const ValueKey('trend-moving-average')),
            )
            .selected,
        isTrue,
      );
      expect(find.text('3-reading average'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}

HealthRecord _record(
  String id,
  String name,
  String value,
  String unit,
  RecordCategory category, {
  DateTime? at,
  String? referenceRange,
}) =>
    HealthRecord(
      id: id,
      name: name,
      value: value,
      unit: unit,
      recordedAt: at ?? DateTime.utc(2026, 9, 26),
      category: category,
      source: 'Test source',
      referenceRange: referenceRange,
    );

HealthTrendPoint _point(
  String id,
  double value,
  int day, {
  DateTime? at,
  String? referenceRange,
}) {
  final record = _record(
    id,
    'Measure',
    value.toString(),
    '',
    RecordCategory.vital,
    at: at ?? DateTime.utc(2026, 9, 26).add(Duration(days: day)),
    referenceRange: referenceRange,
  );
  return HealthTrendPoint(record: record, value: value);
}
