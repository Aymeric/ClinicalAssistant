import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/ui/overview/overview_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'OverviewPage category badges and quick buttons display tooltips',
    (WidgetTester tester) async {
      final record = HealthRecord(
        id: 'lab-1',
        name: 'Hemoglobin A1c',
        value: '5.7',
        unit: '%',
        recordedAt: DateTime(2024, 3, 10),
        source: 'Lab Corp',
        category: RecordCategory.lab,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OverviewPage(
              records: [record],
              loading: false,
              error: null,
              onConnect: () {},
              onSeeAll: () {},
              onRetry: () {},
              onOpenTrends: () {},
              onOpenRecords: () {},
              onOpenExport: () {},
              onLogMeasurement: () {},
            ),
          ),
        ),
      );

      // Scroll to category summary badge first if needed and verify Tooltip
      final badgeTooltipFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip && widget.message == 'Filter records by Labs',
      );
      await tester.scrollUntilVisible(
        badgeTooltipFinder,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(badgeTooltipFinder, findsOneWidget);

      // Scroll down to quick actions section
      final trendsButtonFinder = find.byKey(
        const ValueKey('overview-action-trends'),
      );
      await tester.scrollUntilVisible(
        trendsButtonFinder,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Verify Tooltip on OverviewQuickButtons
      final trendsTooltipFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip && widget.message == 'Trends: Vitals & labs',
      );
      expect(trendsTooltipFinder, findsOneWidget);

      final recordsTooltipFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip && widget.message == 'Records: All entries',
      );
      expect(recordsTooltipFinder, findsOneWidget);

      final exportTooltipFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip && widget.message == 'Export: PDF, CSV, FHIR',
      );
      expect(exportTooltipFinder, findsOneWidget);

      final logTooltipFinder = find.byWidgetPredicate(
        (widget) => widget is Tooltip && widget.message == 'Log: Add reading',
      );
      expect(logTooltipFinder, findsOneWidget);
    },
  );
}
