import 'package:clinical_assistant/models/clinical_panel.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/records/manual_record_entry_sheet.dart';
import 'package:clinical_assistant/ui/records/records_page.dart';
import 'package:clinical_assistant/ui/shared/record_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ManualRecordEntrySheet Multi-Analyte Panel Entry', () {
    testWidgets(
      'switches to Clinical Panel mode, enters Lipid Panel analytes, and saves linked records',
      (tester) async {
        List<HealthRecord>? savedRecords;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ManualRecordEntrySheet(
                onSave: (records) => savedRecords = records,
              ),
            ),
          ),
        );

        // Switch to Lab Result
        await tester.ensureVisible(find.text('Lab Result'));
        await tester.tap(find.text('Lab Result'));
        await tester.pumpAndSettle();

        // Verify toggle exists
        expect(
          find.byKey(const ValueKey('manual-lab-mode-toggle')),
          findsOneWidget,
        );
        expect(find.text('Single Test'), findsOneWidget);
        expect(find.text('Clinical Panel'), findsOneWidget);

        // Switch to Clinical Panel
        await tester.tap(find.text('Clinical Panel'));
        await tester.pumpAndSettle();

        // Verify panel preset dropdown and analytes are visible
        expect(
          find.byKey(const ValueKey('manual-lab-panel-preset-dropdown')),
          findsOneWidget,
        );
        expect(find.text('Total Cholesterol'), findsOneWidget);
        expect(find.text('HDL Cholesterol'), findsOneWidget);
        expect(find.text('LDL Cholesterol'), findsOneWidget);
        expect(find.text('Triglycerides'), findsOneWidget);

        // Enter values for Total Cholesterol and HDL Cholesterol
        await tester.enterText(
          find.byKey(const ValueKey('manual-panel-analyte-Total Cholesterol')),
          '195',
        );
        await tester.enterText(
          find.byKey(const ValueKey('manual-panel-analyte-HDL Cholesterol')),
          '55',
        );
        await tester.pumpAndSettle();

        // Save to Vault
        await tester.ensureVisible(find.text('Save Lab Result to Vault'));
        await tester.tap(find.text('Save Lab Result to Vault'));
        await tester.pumpAndSettle();

        expect(savedRecords, isNotNull);
        expect(savedRecords!.length, 2);

        final totalChol = savedRecords!.firstWhere(
          (r) => r.name == 'Total Cholesterol',
        );
        expect(totalChol.value, '195');
        expect(totalChol.unit, 'mg/dL');
        expect(totalChol.referenceRange, '< 200 mg/dL');

        final hdl = savedRecords!.firstWhere(
          (r) => r.name == 'HDL Cholesterol',
        );
        expect(hdl.value, '55');
        expect(hdl.unit, 'mg/dL');
        expect(hdl.referenceRange, '> 40 mg/dL');

        // Both records share the exact same timestamp, source, and panel metadata
        expect(totalChol.recordedAt, hdl.recordedAt);
        expect(totalChol.source, 'Manual Entry');
        expect(hdl.source, 'Manual Entry');

        final panel1 = extractRecordPanelInfo(totalChol);
        final panel2 = extractRecordPanelInfo(hdl);
        expect(panel1, isNotNull);
        expect(panel2, isNotNull);
        expect(panel1!.name, 'Lipid Panel');
        expect(panel2!.name, 'Lipid Panel');
        expect(panel1.id, panel2.id);
      },
    );

    testWidgets(
      'shows snackbar validation error when submitting with zero filled analytes',
      (tester) async {
        List<HealthRecord>? savedRecords;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ManualRecordEntrySheet(
                onSave: (records) => savedRecords = records,
              ),
            ),
          ),
        );

        await tester.ensureVisible(find.text('Lab Result'));
        await tester.tap(find.text('Lab Result'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Clinical Panel'));
        await tester.pumpAndSettle();

        // Tap save without typing any values
        await tester.ensureVisible(find.text('Save Lab Result to Vault'));
        await tester.tap(find.text('Save Lab Result to Vault'));
        await tester.pumpAndSettle();

        expect(savedRecords, isNull);
        expect(
          find.text('Please enter at least one analyte value.'),
          findsOneWidget,
        );
      },
    );
  });

  group('RecordsPage ClinicalPanelCard rendering', () {
    final now = DateTime.utc(2026, 10, 26, 8, 30);
    final panelRecords = [
      HealthRecord(
        id: 'rec-1',
        name: 'Total Cholesterol',
        value: '220', // Above range
        unit: 'mg/dL',
        recordedAt: now,
        category: RecordCategory.lab,
        source: 'LabCorp',
        referenceRange: '< 200 mg/dL',
        sourceData: const {
          'panel': {'id': 'pan-1', 'name': 'Lipid Panel'},
        },
      ),
      HealthRecord(
        id: 'rec-2',
        name: 'HDL Cholesterol',
        value: '45', // Normal
        unit: 'mg/dL',
        recordedAt: now,
        category: RecordCategory.lab,
        source: 'LabCorp',
        referenceRange: '> 40 mg/dL',
        sourceData: const {
          'panel': {'id': 'pan-1', 'name': 'Lipid Panel'},
        },
      ),
      HealthRecord(
        id: 'rec-3',
        name: 'Triglycerides',
        value: '130', // Normal
        unit: 'mg/dL',
        recordedAt: now,
        category: RecordCategory.lab,
        source: 'LabCorp',
        referenceRange: '< 150 mg/dL',
        sourceData: const {
          'panel': {'id': 'pan-1', 'name': 'Lipid Panel'},
        },
      ),
    ];

    testWidgets(
      'renders collapsible ClinicalPanelCard with counts and expands to show analytes',
      (tester) async {
        HealthRecord? tappedRecord;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecordsPage(
                records: panelRecords,
                onRecordTap: (rec) => tappedRecord = rec,
              ),
            ),
          ),
        );

        // Verify panel card is present
        expect(find.byType(ClinicalPanelCard), findsOneWidget);
        expect(find.text('Lipid Panel'), findsOneWidget);
        expect(find.text('3 tests'), findsOneWidget);
        expect(find.text('1 out of range'), findsOneWidget);

        // Initially collapsed, analyte rows are not yet rendered
        expect(
          find.byKey(
            const ValueKey('clinical-panel-analyte-Total Cholesterol'),
          ),
          findsNothing,
        );

        // Tap the card or expand button to expand
        await tester.tap(find.text('Lipid Panel'));
        await tester.pumpAndSettle();

        // Now individual analyte rows are displayed
        expect(
          find.byKey(
            const ValueKey('clinical-panel-analyte-Total Cholesterol'),
          ),
          findsOneWidget,
        );
        expect(find.text('220 mg/dL'), findsOneWidget);
        expect(find.text('High'), findsOneWidget);

        expect(
          find.byKey(const ValueKey('clinical-panel-analyte-HDL Cholesterol')),
          findsOneWidget,
        );
        expect(find.text('45 mg/dL'), findsOneWidget);

        // Tapping an analyte invokes onRecordTap
        await tester.tap(
          find.byKey(
            const ValueKey('clinical-panel-analyte-Total Cholesterol'),
          ),
        );
        await tester.pumpAndSettle();

        expect(tappedRecord, isNotNull);
        expect(tappedRecord!.name, 'Total Cholesterol');
        expect(tappedRecord!.value, '220');
      },
    );
  });
}
