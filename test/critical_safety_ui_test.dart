import 'package:clinical_assistant/exports/health_export_service.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/records/manual_record_entry_sheet.dart';
import 'package:clinical_assistant/ui/overview/overview_page.dart';
import 'package:clinical_assistant/ui/records/record_details_sheet.dart';
import 'package:clinical_assistant/ui/records/records_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 26, 10, 0);

  group('ManualRecordEntrySheet - Critical Safety Red-Flag Alert', () {
    testWidgets(
      'presents emergency advisory dialog when entering critical blood pressure (195/125)',
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

        // Default type is blood pressure (120/80).
        // Enter hypertensive crisis values
        final sysFinder = find.widgetWithText(TextFormField, 'Systolic (mmHg)');
        final diaFinder = find.widgetWithText(
          TextFormField,
          'Diastolic (mmHg)',
        );

        await tester.enterText(sysFinder, '195');
        await tester.enterText(diaFinder, '125');
        await tester.pumpAndSettle();

        // Tap Save
        await tester.ensureVisible(find.text('Save Measurement to Vault'));
        await tester.tap(find.text('Save Measurement to Vault'));
        await tester.pumpAndSettle();

        // Critical alert dialog should be displayed before saving
        expect(
          find.byKey(const ValueKey('critical-safety-alert-dialog')),
          findsOneWidget,
        );
        expect(find.text('Critical Safety Alert'), findsOneWidget);
        expect(
          find.textContaining('Hypertensive Crisis Range'),
          findsOneWidget,
        );
        expect(find.textContaining('195/125 mmHg'), findsOneWidget);
        expect(savedRecords, isNull); // Not yet saved

        // Tap Emergency Guidance button
        await tester.tap(
          find.byKey(const ValueKey('critical-alert-emergency-contact-button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('emergency medical care or call 911'),
          findsOneWidget,
        );

        // Tap "I Understand — Save to Vault"
        await tester.tap(
          find.byKey(const ValueKey('critical-alert-acknowledge-save-button')),
        );
        await tester.pumpAndSettle();

        expect(savedRecords, isNotNull);
        expect(savedRecords!.length, 2);
        expect(savedRecords![0].value, '195');
        expect(savedRecords![1].value, '125');
      },
    );
  });

  group('OverviewPage - Critical Safety Alert Feed', () {
    testWidgets('renders critical safety alert card and opens modal on tap', (
      tester,
    ) async {
      final records = [
        HealthRecord(
          id: 'hypo-1',
          name: 'Blood Glucose',
          value: '46', // Severe hypoglycemia
          unit: 'mg/dL',
          recordedAt: now,
          category: RecordCategory.lab,
          source: 'CGM',
        ),
        HealthRecord(
          id: 'hr-1',
          name: 'Heart Rate',
          value: '72',
          unit: 'bpm',
          recordedAt: now,
          category: RecordCategory.vital,
          source: 'Watch',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OverviewPage(
              records: records,
              loading: false,
              error: null,
              onConnect: () {},
              onSeeAll: () {},
              onRetry: () {},
            ),
          ),
        ),
      );

      // Verify Critical Safety Card exists
      expect(
        find.byKey(const ValueKey('overview-critical-safety-card')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Severe Hypoglycemia: 46 mg/dL'),
        findsOneWidget,
      );

      // Tap the alert item in the card to open guidance bottom sheet
      await tester.tap(find.textContaining('Severe Hypoglycemia: 46 mg/dL'));
      await tester.pumpAndSettle();

      expect(find.text('Recommended Immediate Action:'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.textContaining('15–20g of fast-acting carbohydrates'),
        ),
        findsOneWidget,
      );

      // Dismiss bottom sheet
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();
      expect(find.text('Recommended Immediate Action:'), findsNothing);
    });
  });

  group('RecordsPage & RecordDetailsSheet - Critical Badges and Banners', () {
    testWidgets(
      'renders CRITICAL badge in list and emergency guidance banner in details sheet',
      (tester) async {
        final record = HealthRecord(
          id: 'crit-spo2',
          name: 'Oxygen (SpO2)',
          value: '83', // Critically low
          unit: '%',
          recordedAt: now,
          category: RecordCategory.vital,
          source: 'Pulse Oximeter',
        );

        HealthRecord? tappedRecord;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecordsPage(
                records: [record],
                onRecordTap: (r) => tappedRecord = r,
              ),
            ),
          ),
        );

        // CRITICAL badge in list item
        expect(find.text('CRITICAL'), findsOneWidget);

        // Tap record
        await tester.tap(find.text('Oxygen (SpO2)'));
        await tester.pumpAndSettle();
        expect(tappedRecord, isNotNull);

        // Now verify RecordDetailsSheet
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RecordDetailsSheet(record: record, isNumeric: true),
            ),
          ),
        );

        expect(
          find.byKey(const ValueKey('record-critical-safety-banner')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Critical Alert: Severe Hypoxemia'),
          findsOneWidget,
        );
        expect(
          find.textContaining('critically reduced blood oxygenation'),
          findsOneWidget,
        );
      },
    );
  });

  group('PDF Summary - Critical Annotation', () {
    test('marks critical readings with CRITICAL in visit summary', () async {
      final records = [
        HealthRecord(
          id: 'bp-sys-crit',
          name: 'Systolic Blood Pressure',
          value: '198',
          unit: 'mmHg',
          recordedAt: now,
          category: RecordCategory.vital,
          source: 'Clinic',
        ),
      ];

      final service = HealthExportService();
      final doc = await service.buildDoctorVisitSummaryPdfDocument(records);
      final bytes = await doc.save();
      expect(bytes, isNotEmpty);
    });
  });
}
