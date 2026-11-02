import 'package:clinical_assistant/exports/fhir_export_validator.dart';
import 'package:clinical_assistant/exports/health_export_service.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/ui/export/export_page.dart';
import 'package:clinical_assistant/ui/export/fhir_preflight_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = FhirExportValidator();
  final exporter = HealthExportService();

  group('FhirExportValidator', () {
    test('validates clean FHIR R4 Bundle with Observation and Medication', () {
      final records = [
        HealthRecord(
          id: 'obs-1',
          name: 'Blood Glucose',
          value: '95',
          unit: 'mg/dL',
          recordedAt: DateTime.utc(2025, 6, 1),
          category: RecordCategory.lab,
          source: 'LabCorp',
          code: '1558-6',
          status: 'final',
          sourceData: const {
            'resourceType': 'Observation',
            'id': 'obs-1',
            'status': 'final',
            'code': {
              'coding': [
                {
                  'system': 'http://loinc.org',
                  'code': '1558-6',
                  'display': 'Blood Glucose',
                },
              ],
              'text': 'Blood Glucose',
            },
            'effectiveDateTime': '2025-06-01T08:00:00Z',
            'valueQuantity': {
              'value': 95,
              'unit': 'mg/dL',
              'system': 'http://unitsofmeasure.org',
              'code': 'mg/dL',
            },
          },
        ),
        HealthRecord(
          id: 'med-1',
          name: 'Lisinopril',
          value: '10 mg',
          unit: '',
          recordedAt: DateTime.utc(2025, 6, 1),
          category: RecordCategory.medication,
          source: 'Manual Entry',
          status: 'active',
        ),
      ];

      final bundle = exporter.buildFhirBundle(records);
      final report = validator.validateBundle(bundle, records: records);

      expect(report.targetProfile, 'HL7 FHIR Release 4 (R4 v4.0.1)');
      expect(report.totalResources, 2);
      expect(report.resourceCounts['Observation'], 1);
      expect(report.resourceCounts['MedicationStatement'], 1);
      expect(report.canExport, isTrue);
      expect(report.errors, isEmpty);
    });

    test(
      'flags informational notice for manual observation without LOINC coding',
      () {
        final records = [
          HealthRecord(
            id: 'manual-obs',
            name: 'Fingerstick Glucose',
            value: '105',
            unit: 'mg/dL',
            recordedAt: DateTime.utc(2025, 6, 1),
            category: RecordCategory.lab,
            source: 'Manual Entry',
          ),
        ];

        final bundle = exporter.buildFhirBundle(records);
        final report = validator.validateBundle(bundle, records: records);

        expect(report.canExport, isTrue);
        expect(
          report.infos.any(
            (i) => i.message.contains(
              'relies on text display without standard LOINC',
            ),
          ),
          isTrue,
        );
      },
    );

    test('flags fatal error when root resource is not a Bundle', () {
      final invalidBundle = <String, Object?>{
        'resourceType': 'Observation',
        'id': 'not-a-bundle',
      };

      final report = validator.validateBundle(invalidBundle);

      expect(report.canExport, isFalse);
      expect(
        report.errors.any((e) => e.message.contains("resourceType 'Bundle'")),
        isTrue,
      );
    });

    test('flags fatal error when resource lacks id or required fields', () {
      final malformedBundle = <String, Object?>{
        'resourceType': 'Bundle',
        'type': 'collection',
        'entry': [
          {
            'resource': {
              'resourceType': 'Observation',
              // missing id, status, and code
            },
          },
        ],
      };

      final report = validator.validateBundle(malformedBundle);

      expect(report.canExport, isFalse);
      expect(
        report.errors.any((e) => e.message.contains('missing a required')),
        isTrue,
      );
    });
  });

  group('FhirPreflightSheet UI', () {
    testWidgets(
      'renders profile badge, resource counts, disclaimer, and confirms export',
      (tester) async {
        var confirmed = false;
        const report = FhirPreflightReport(
          totalResources: 3,
          resourceCounts: {'Observation': 2, 'MedicationStatement': 1},
          issues: [
            FhirPreflightIssue(
              severity: FhirIssueSeverity.info,
              message: 'Observation relies on display name without LOINC code.',
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FhirPreflightSheet(
                report: report,
                onConfirmExport: () => confirmed = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('FHIR Export Preflight'), findsOneWidget);
        expect(
          find.text('Target: HL7 FHIR Release 4 (R4 v4.0.1)'),
          findsOneWidget,
        );
        expect(find.text('Observation: 2'), findsOneWidget);
        expect(find.text('MedicationStatement: 1'), findsOneWidget);
        expect(
          find.textContaining('universal acceptance is not guaranteed'),
          findsOneWidget,
        );
        expect(
          find.text('Observation relies on display name without LOINC code.'),
          findsOneWidget,
        );

        final confirmButton = find.byKey(
          const ValueKey('fhir-preflight-confirm-button'),
        );
        expect(confirmButton, findsOneWidget);
        await tester.tap(confirmButton);
        await tester.pumpAndSettle();

        expect(confirmed, isTrue);
      },
    );

    testWidgets('disables share button when report has fatal errors', (
      tester,
    ) async {
      const errorReport = FhirPreflightReport(
        totalResources: 1,
        resourceCounts: {'Observation': 1},
        issues: [
          FhirPreflightIssue(
            severity: FhirIssueSeverity.error,
            message: 'Resource missing id',
          ),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FhirPreflightSheet(
              report: errorReport,
              onConfirmExport: _noop,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Validation failed: 1 fatal error(s)'),
        findsOneWidget,
      );

      final confirmButton = tester.widget<FilledButton>(
        find.byKey(const ValueKey('fhir-preflight-confirm-button')),
      );
      expect(confirmButton.onPressed, isNull);
    });
  });

  group('ExportPage FHIR Preflight Flow', () {
    testWidgets('opens preflight sheet when Export FHIR JSON is tapped', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final record = HealthRecord(
        id: 'obs-1',
        name: 'Blood Pressure Systolic',
        value: '120',
        unit: 'mmHg',
        recordedAt: DateTime.now(),
        category: RecordCategory.vital,
        source: 'Apple Health',
      );

      List<HealthRecord>? exported;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportPage(
              records: [record],
              exporting: false,
              onPdf: (_) {},
              onFhir: (recs) => exported = recs,
              onCsv: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fhirButton = find.text('Export FHIR JSON');
      await tester.ensureVisible(fhirButton);
      await tester.tap(fhirButton);
      await tester.pumpAndSettle();

      // Preflight sheet is now open
      expect(find.text('FHIR Export Preflight'), findsOneWidget);
      expect(
        find.text('Target: HL7 FHIR Release 4 (R4 v4.0.1)'),
        findsOneWidget,
      );

      // Tap confirm button in sheet
      final confirmButton = find.byKey(
        const ValueKey('fhir-preflight-confirm-button'),
      );
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      expect(exported, isNotNull);
      expect(exported!.length, 1);
      expect(exported!.first.id, 'obs-1');
    });
  });
}

void _noop() {}
