import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/trends/health_trend.dart';
import 'package:clinical_assistant/trends/trend_indicators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrendIndicators accessible Tooltip and Semantics', () {
    testWidgets('renders tooltips and semantics labels with positive change', (
      WidgetTester tester,
    ) async {
      final r1 = HealthRecord(
        id: '1',
        name: 'Heart Rate',
        value: '70',
        unit: 'bpm',
        recordedAt: DateTime.utc(2026, 1, 1),
        category: RecordCategory.vital,
        source: 'Manual',
      );
      final r2 = HealthRecord(
        id: '2',
        name: 'Heart Rate',
        value: '80',
        unit: 'bpm',
        recordedAt: DateTime.utc(2026, 1, 2),
        category: RecordCategory.vital,
        source: 'Manual',
      );

      final p1 = HealthTrendPoint(record: r1, value: 70);
      final p2 = HealthTrendPoint(record: r2, value: 80);
      final summary = summarizeHealthTrend([p1, p2]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TrendIndicators(summary: summary, count: 2)),
        ),
      );
      await tester.pumpAndSettle();

      // Tooltips for all 4 cards
      expect(find.byType(Tooltip), findsNWidgets(4));

      final tooltips = tester
          .widgetList<Tooltip>(find.byType(Tooltip))
          .map((t) => t.message)
          .toList();

      expect(
        tooltips,
        containsAll([
          'Change: +14.3% (Since previous reading)',
          'Average: 75 (In this range)',
          'Observed range: 70–80 (Lowest to highest)',
          'Readings: 2 (In this range)',
        ]),
      );

      // Semantics for all 4 cards
      final semanticsList = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where(
            (s) =>
                s.properties.label != null &&
                (s.properties.label!.startsWith('Change:') ||
                    s.properties.label!.startsWith('Average:') ||
                    s.properties.label!.startsWith('Observed range:') ||
                    s.properties.label!.startsWith('Readings:')),
          )
          .toList();

      expect(semanticsList, hasLength(4));

      final semanticsLabels = semanticsList
          .map((s) => s.properties.label!)
          .toList();

      expect(
        semanticsLabels,
        containsAll([
          'Change: +14.3%, Since previous reading, Trending up',
          'Average: 75, In this range',
          'Observed range: 70–80, Lowest to highest',
          'Readings: 2, In this range',
        ]),
      );

      // Verify excludeSemantics is true on each metric Semantics widget
      for (final semantics in semanticsList) {
        expect(semantics.excludeSemantics, isTrue);
      }
    });

    testWidgets('renders downwards trend semantics when change is negative', (
      WidgetTester tester,
    ) async {
      final r1 = HealthRecord(
        id: '1',
        name: 'Heart Rate',
        value: '80',
        unit: 'bpm',
        recordedAt: DateTime.utc(2026, 1, 1),
        category: RecordCategory.vital,
        source: 'Manual',
      );
      final r2 = HealthRecord(
        id: '2',
        name: 'Heart Rate',
        value: '70',
        unit: 'bpm',
        recordedAt: DateTime.utc(2026, 1, 2),
        category: RecordCategory.vital,
        source: 'Manual',
      );

      final p1 = HealthTrendPoint(record: r1, value: 80);
      final p2 = HealthTrendPoint(record: r2, value: 70);
      final summary = summarizeHealthTrend([p1, p2]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TrendIndicators(summary: summary, count: 2)),
        ),
      );
      await tester.pumpAndSettle();

      final semanticsLabels = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .map((s) => s.properties.label)
          .whereType<String>()
          .toList();

      expect(
        semanticsLabels,
        contains('Change: -12.5%, Since previous reading, Trending down'),
      );
    });

    testWidgets('renders flat trend semantics when change is zero', (
      WidgetTester tester,
    ) async {
      final r1 = HealthRecord(
        id: '1',
        name: 'Heart Rate',
        value: '75',
        unit: 'bpm',
        recordedAt: DateTime.utc(2026, 1, 1),
        category: RecordCategory.vital,
        source: 'Manual',
      );
      final r2 = HealthRecord(
        id: '2',
        name: 'Heart Rate',
        value: '75',
        unit: 'bpm',
        recordedAt: DateTime.utc(2026, 1, 2),
        category: RecordCategory.vital,
        source: 'Manual',
      );

      final p1 = HealthTrendPoint(record: r1, value: 75);
      final p2 = HealthTrendPoint(record: r2, value: 75);
      final summary = summarizeHealthTrend([p1, p2]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TrendIndicators(summary: summary, count: 2)),
        ),
      );
      await tester.pumpAndSettle();

      final semanticsLabels = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .map((s) => s.properties.label)
          .whereType<String>()
          .toList();

      expect(
        semanticsLabels,
        contains('Change: +0.0%, Since previous reading, Trending flat'),
      );
    });

    testWidgets(
      'renders single reading placeholder semantics when change is unavailable',
      (WidgetTester tester) async {
        final r1 = HealthRecord(
          id: '1',
          name: 'Heart Rate',
          value: '72',
          unit: 'bpm',
          recordedAt: DateTime.utc(2026, 1, 1),
          category: RecordCategory.vital,
          source: 'Manual',
        );

        final p1 = HealthTrendPoint(record: r1, value: 72);
        final summary = summarizeHealthTrend([p1]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: TrendIndicators(summary: summary, count: 1)),
          ),
        );
        await tester.pumpAndSettle();

        final semanticsLabels = tester
            .widgetList<Semantics>(find.byType(Semantics))
            .map((s) => s.properties.label)
            .whereType<String>()
            .toList();

        expect(semanticsLabels, contains('Change: —, Need another reading'));
      },
    );
  });
}
