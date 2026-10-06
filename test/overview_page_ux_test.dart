import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/trends/health_trend.dart';
import 'package:clinical_assistant/ui/overview/overview_page.dart';
import 'package:clinical_assistant/ui/records/records_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('OverviewPage displays tooltips on interactive elements', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final labRecord = HealthRecord(
      id: 'lab-1',
      name: 'Hemoglobin A1c',
      category: RecordCategory.lab,
      value: '7.2',
      unit: '%',
      referenceRange: '4.0 - 5.6 %',
      recordedAt: now,
      source: 'Test Lab',
    );
    final vitalRecord = HealthRecord(
      id: 'vital-1',
      name: 'Heart Rate',
      category: RecordCategory.vital,
      value: '75',
      unit: 'bpm',
      recordedAt: now,
      source: 'Test Device',
    );

    final vitalSeriesId = healthTrendSeriesId(vitalRecord);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OverviewPage(
            records: [labRecord, vitalRecord],
            loading: false,
            error: null,
            pinnedSeries: {vitalSeriesId},
            onConnect: () {},
            onSeeAll: () {},
            onRetry: () {},
            onViewOutOfRangeLabs: () {},
            onOpenTrends: () {},
            onOpenRecords: () {},
            onOpenExport: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify pinned metric tooltip
    expect(find.byTooltip('View details for Heart Rate'), findsOneWidget);

    // Verify flagged lab chip tooltip
    expect(
      find.byTooltip('View flagged lab results in Records'),
      findsOneWidget,
    );

    // Scroll down to reveal Quick actions and Category breakdown
    await tester.scrollUntilVisible(
      find.text('Quick actions'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // Verify quick action button tooltips
    expect(find.byTooltip('Trends — Vitals & labs'), findsOneWidget);
    expect(find.byTooltip('Records — All entries'), findsOneWidget);
    expect(find.byTooltip('Export — PDF, CSV, FHIR'), findsOneWidget);

    // Verify category summary badge tooltips
    expect(find.byTooltip('Filter records by Labs'), findsOneWidget);
    expect(find.byTooltip('Filter records by Vitals'), findsOneWidget);
  });

  testWidgets(
    'RecordsPage out-of-range filter chip displays accessible tooltip',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: RecordsPage(records: [])),
        ),
      );
      await tester.pumpAndSettle();

      final filterChipFinder = find.byKey(
        const ValueKey('records-out-of-range-filter'),
      );
      expect(filterChipFinder, findsOneWidget);

      final FilterChip chip = tester.widget(filterChipFinder);
      expect(chip.tooltip, equals('Filter to show out of range records only'));
    },
  );
}
