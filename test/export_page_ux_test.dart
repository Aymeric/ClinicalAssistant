import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/ui/export/export_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ExportPage filter chips display accessible tooltips', (
    WidgetTester tester,
  ) async {
    final sampleRecord = HealthRecord(
      id: 'vital-1',
      name: 'Heart Rate',
      category: RecordCategory.vital,
      value: '72',
      unit: 'bpm',
      recordedAt: DateTime.now(),
      source: 'Test',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExportPage(
            records: [sampleRecord],
            exporting: false,
            onPdf: (_) {},
            onFhir: (_) {},
            onCsv: (_) {},
          ),
        ),
      ),
    );

    // Verify initial chip tooltip (selected state)
    final chipFinder = find.widgetWithText(FilterChip, 'Vitals (1)');
    expect(chipFinder, findsOneWidget);

    final FilterChip initialChip = tester.widget(chipFinder);
    expect(initialChip.tooltip, equals('Exclude Vitals from export'));

    // Tap to deselect
    await tester.tap(chipFinder);
    await tester.pumpAndSettle();

    final FilterChip deselectedChip = tester.widget(chipFinder);
    expect(deselectedChip.tooltip, equals('Include Vitals in export'));

    // Verify date preset ChoiceChip tooltips
    final presetAllFinder = find.byKey(
      const ValueKey('export-date-preset-all'),
    );
    expect(presetAllFinder, findsOneWidget);
    final ChoiceChip presetAllChip = tester.widget(presetAllFinder);
    expect(
      presetAllChip.tooltip,
      equals('Include records from all time in export'),
    );

    final preset30Finder = find.byKey(
      const ValueKey('export-date-preset-days30'),
    );
    expect(preset30Finder, findsOneWidget);
    final ChoiceChip preset30Chip = tester.widget(preset30Finder);
    expect(preset30Chip.tooltip, equals('Filter export to last 30 days'));
  });

  testWidgets('ExportPage filters by source chips and search query', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final recordA = HealthRecord(
      id: 'vital-1',
      name: 'Heart Rate',
      category: RecordCategory.vital,
      value: '72',
      unit: 'bpm',
      recordedAt: DateTime.now(),
      source: 'Apple Health',
    );
    final recordB = HealthRecord(
      id: 'lab-1',
      name: 'Hemoglobin A1c',
      category: RecordCategory.lab,
      value: '5.6',
      unit: '%',
      recordedAt: DateTime.now(),
      source: 'Hospital Portal',
      code: '4548-4',
    );

    List<HealthRecord>? exportedRecords;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExportPage(
            records: [recordA, recordB],
            exporting: false,
            onPdf: (r) => exportedRecords = r,
            onFhir: (_) {},
            onCsv: (_) {},
          ),
        ),
      ),
    );

    // Initial state: 2 of 2 records selected
    expect(find.text('2 of 2 records selected'), findsOneWidget);

    // Filter by search query
    await tester.enterText(
      find.byKey(const ValueKey('export-search-input')),
      '4548-4',
    );
    await tester.pumpAndSettle();

    expect(find.text('1 of 2 records selected'), findsOneWidget);

    // Clear search query
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 2 records selected'), findsOneWidget);

    // Deselect Apple Health source
    final appleChip = find.byKey(const ValueKey('export-source-Apple Health'));
    expect(appleChip, findsOneWidget);
    await tester.tap(appleChip);
    await tester.pumpAndSettle();

    expect(find.text('1 of 2 records selected'), findsOneWidget);

    // Trigger export and verify only Hospital Portal record is exported
    await tester.tap(find.text('Create PDF'));
    await tester.pumpAndSettle();

    expect(exportedRecords, isNotNull);
    expect(exportedRecords!.single.source, equals('Hospital Portal'));
  });

  testWidgets(
    'ExportPage applies privacy redaction controls and synthetic demo guard',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final realRecord = HealthRecord(
        id: 'vital-1',
        name: 'Blood Pressure',
        category: RecordCategory.vital,
        value: '120/80',
        unit: 'mmHg',
        recordedAt: DateTime.now(),
        source: 'Apple Health',
        notes: 'Doctor visit question',
        sourceData: const {'token': 'secret-123'},
      );
      final demoRecord = HealthRecord(
        id: 'synthetic-1',
        name: 'Demo Glucose',
        category: RecordCategory.lab,
        value: '99',
        unit: 'mg/dL',
        recordedAt: DateTime.now(),
        source: 'Synthetic Demo',
        sourceId: 'synthetic-demo',
      );

      List<HealthRecord>? exportedRecords;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportPage(
              records: [realRecord, demoRecord],
              exporting: false,
              onPdf: (_) {},
              onFhir: (_) {},
              onCsv: (r) => exportedRecords = r,
            ),
          ),
        ),
      );

      // Synthetic demo records are excluded by default when real records exist (1 of 2 selected)
      expect(find.text('1 of 2 records selected'), findsOneWidget);

      // Toggle on synthetic demo data
      final syntheticToggle = find.byKey(
        const ValueKey('export-include-synthetic-toggle'),
      );
      expect(syntheticToggle, findsOneWidget);
      await tester.tap(syntheticToggle);
      await tester.pumpAndSettle();

      expect(find.text('2 of 2 records selected'), findsOneWidget);

      // Toggle off personal notes
      final notesToggle = find.byKey(
        const ValueKey('export-include-notes-toggle'),
      );
      await tester.tap(notesToggle);
      await tester.pumpAndSettle();

      // Toggle off raw source JSON
      final sourceDataToggle = find.byKey(
        const ValueKey('export-include-source-data-toggle'),
      );
      await tester.tap(sourceDataToggle);
      await tester.pumpAndSettle();

      // Export CSV and verify redactions were applied to the payload
      await tester.tap(find.text('Export CSV'));
      await tester.pumpAndSettle();

      expect(exportedRecords, isNotNull);
      final exportedReal = exportedRecords!.firstWhere(
        (r) => r.id == 'vital-1',
      );
      expect(exportedReal.notes, isNull);
      expect(exportedReal.sourceData, isNull);
      // Real record in vault remains unmutated
      expect(realRecord.notes, equals('Doctor visit question'));
      expect(realRecord.sourceData, isNotNull);
    },
  );
}
