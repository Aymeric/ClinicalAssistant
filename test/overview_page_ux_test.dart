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
              onSelectCategory: (_) {},
              onSelectSpecialty: (_) {},
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

      // Verify CategorySummaryBadge semantics
      final badgeSemanticsList = tester.widgetList<Semantics>(
        find.descendant(of: badgeFinder, matching: find.byType(Semantics)),
      );
      final badgeSemantics = badgeSemanticsList.firstWhere(
        (s) => s.properties.label == 'Filter records by Vitals (1 entry)',
      );
      expect(badgeSemantics.properties.button, isTrue);
      expect(badgeSemantics.excludeSemantics, isTrue);

      // Verify SpecialtySummaryBadge semantics and tooltip
      final specialtyBadgeFinder = find.byType(SpecialtySummaryBadge);
      expect(specialtyBadgeFinder, findsWidgets);
      final firstSpecialtyBadge = specialtyBadgeFinder.first;
      final specialtyTooltip = tester.widget<Tooltip>(
        find.descendant(
          of: firstSpecialtyBadge,
          matching: find.byType(Tooltip),
        ),
      );
      expect(specialtyTooltip.message, contains('Filter records by'));
      final specialtySemanticsList = tester.widgetList<Semantics>(
        find.descendant(
          of: firstSpecialtyBadge,
          matching: find.byType(Semantics),
        ),
      );
      final specialtySemantics = specialtySemanticsList.firstWhere(
        (s) => s.properties.label == specialtyTooltip.message,
      );
      expect(specialtySemantics.properties.button, isTrue);
      expect(specialtySemantics.excludeSemantics, isTrue);
    },
  );

  testWidgets(
    'Critical safety alert modal close button displays accessible tooltip',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final criticalRecord = HealthRecord(
        id: 'crit-1',
        name: 'Systolic Blood Pressure',
        category: RecordCategory.vital,
        value: '195',
        unit: 'mmHg',
        recordedAt: DateTime.now(),
        source: 'Manual entry',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OverviewPage(
              records: [criticalRecord],
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

      // Tap on the critical alert card item to open modal
      final criticalTile = find.textContaining('Hypertensive Crisis Range');
      expect(criticalTile, findsOneWidget);
      await tester.tap(criticalTile);
      await tester.pumpAndSettle();

      // Find close button in modal and verify tooltip
      final closeButtonFinder = find.byTooltip('Close alert details');
      expect(closeButtonFinder, findsOneWidget);

      await tester.tap(closeButtonFinder);
      await tester.pumpAndSettle();
      expect(closeButtonFinder, findsNothing);
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
