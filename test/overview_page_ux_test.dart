import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/trends/health_trend.dart';
import 'package:clinical_assistant/ui/overview/overview_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'OverviewQuickButton and CategorySummaryBadge display accessible tooltips',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sampleRecord = HealthRecord(
        id: 'vital-1',
        name: 'Heart Rate',
        category: RecordCategory.vital,
        value: '72',
        unit: 'bpm',
        recordedAt: DateTime.now(),
        source: 'Test Source',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OverviewPage(
              records: [sampleRecord],
              loading: false,
              error: null,
              onConnect: () {},
              onSeeAll: () {},
              onRetry: () {},
              onLogMeasurement: () {},
              onOpenTrends: () {},
              onOpenRecords: () {},
              onOpenExport: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Quick Action Buttons tooltips in OverviewPage
      final trendsButtonFinder = find.byKey(
        const ValueKey('overview-action-trends'),
      );
      expect(trendsButtonFinder, findsOneWidget);
      final trendsTooltip = tester.widget<Tooltip>(
        find.descendant(of: trendsButtonFinder, matching: find.byType(Tooltip)),
      );
      expect(trendsTooltip.message, equals('Open Vitals & Labs Trends'));

      final exportButtonFinder = find.byKey(
        const ValueKey('overview-action-export'),
      );
      expect(exportButtonFinder, findsOneWidget);
      final exportTooltip = tester.widget<Tooltip>(
        find.descendant(of: exportButtonFinder, matching: find.byType(Tooltip)),
      );
      expect(
        exportTooltip.message,
        equals('Export records to PDF, CSV, or FHIR'),
      );

      // Verify CategorySummaryBadge tooltip in OverviewPage
      final badgeFinder = find.byType(CategorySummaryBadge);
      expect(badgeFinder, findsOneWidget);
      final badgeTooltip = tester.widget<Tooltip>(
        find.descendant(of: badgeFinder, matching: find.byType(Tooltip)),
      );
      expect(
        badgeTooltip.message,
        equals('Filter records by Vitals (1 entry)'),
      );
    },
  );

  testWidgets(
    'Pinned metrics cards display accessible tooltips and semantics',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final recordDate = DateTime(2026, 10, 24, 10, 0);
      final sampleRecord = HealthRecord(
        id: 'vital-1',
        name: 'Heart Rate',
        category: RecordCategory.vital,
        value: '72',
        unit: 'bpm',
        recordedAt: recordDate,
        source: 'Test Source',
      );

      final seriesId = healthTrendSeriesId(sampleRecord);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OverviewPage(
              records: [sampleRecord],
              pinnedSeries: {seriesId},
              loading: false,
              error: null,
              onConnect: () {},
              onSeeAll: () {},
              onRetry: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final pinnedTooltipFinder = find.ancestor(
        of: find.text('Heart Rate'),
        matching: find.byType(Tooltip),
      );
      expect(pinnedTooltipFinder, findsOneWidget);

      final tooltipWidget = tester.widget<Tooltip>(pinnedTooltipFinder);
      expect(tooltipWidget.message, equals('Heart Rate: 72 bpm'));

      final semanticsFinder = find.descendant(
        of: pinnedTooltipFinder,
        matching: find.byType(Semantics),
      );
      expect(semanticsFinder, findsWidgets);

      final semanticsWidget = tester
          .widgetList<Semantics>(semanticsFinder)
          .firstWhere(
            (s) =>
                s.properties.label?.startsWith('Pinned metric Heart Rate') ??
                false,
          );
      expect(semanticsWidget.properties.button, isTrue);
      expect(semanticsWidget.excludeSemantics, isTrue);
    },
  );
}
