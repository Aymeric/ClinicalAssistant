import 'dart:convert';

import 'package:clinical_assistant/exports/health_export_service.dart';
import 'package:clinical_assistant/integrations/fhir_file_import.dart';
import 'package:clinical_assistant/integrations/fhir_observation_parser.dart';
import 'package:clinical_assistant/integrations/fhir_portal_importer.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/models/procedure_details.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = FhirObservationParser();

  group('FHIR Procedure Parsing & Ingestion', () {
    test(
      'parses full HL7 FHIR Procedure resource with body site and performer',
      () {
        final json = jsonEncode({
          'resourceType': 'Procedure',
          'id': 'proc-101',
          'status': 'completed',
          'code': {
            'coding': [
              {
                'system': 'http://snomed.info/sct',
                'code': '80146002',
                'display': 'Appendectomy',
              },
            ],
            'text': 'Laparoscopic Appendectomy',
          },
          'performedDateTime': '2025-06-15T10:30:00Z',
          'bodySite': [
            {
              'coding': [
                {
                  'system': 'http://snomed.info/sct',
                  'code': '66754008',
                  'display': 'Appendix structure',
                },
              ],
              'text': 'Appendix',
            },
          ],
          'outcome': {
            'coding': [
              {
                'system': 'http://snomed.info/sct',
                'code': '385669000',
                'display': 'Successful',
              },
            ],
            'text': 'Successful and uncomplicated',
          },
          'performer': [
            {
              'actor': {
                'reference': 'Practitioner/dr-smith',
                'display': 'Dr. Robert Smith, MD',
              },
            },
          ],
          'reasonCode': [
            {
              'coding': [
                {
                  'system': 'http://snomed.info/sct',
                  'code': '44132006',
                  'display': 'Acute appendicitis',
                },
              ],
              'text': 'Acute appendicitis with localized peritonitis',
            },
          ],
          'note': [
            {'text': 'Routine recovery with no post-operative complications.'},
          ],
        });

        final records = parser.parseJson(json, source: 'Hospital Portal');
        expect(records, hasLength(1));

        final record = records.first;
        expect(record.category, RecordCategory.procedure);
        expect(record.name, 'Laparoscopic Appendectomy');
        expect(record.value, contains('Completed'));
        expect(record.value, contains('Appendix'));
        expect(record.value, contains('Successful and uncomplicated'));
        expect(record.source, 'Hospital Portal');
        expect(record.code, '80146002');
        expect(record.status, 'completed');
        expect(record.recordedAt, DateTime.utc(2025, 6, 15, 10, 30));
        expect(
          record.notes,
          'Routine recovery with no post-operative complications.',
        );

        // Verify ProcedureDetails extraction
        final details = ProcedureDetails.fromRecord(record);
        expect(details, isNotNull);
        expect(details!.name, 'Laparoscopic Appendectomy');
        expect(details.status, 'completed');
        expect(details.bodySite, 'Appendix');
        expect(details.outcome, 'Successful and uncomplicated');
        expect(details.performer, 'Dr. Robert Smith, MD');
        expect(details.reason, 'Acute appendicitis with localized peritonitis');
        expect(details.code, '80146002');
      },
    );

    test('ignores entered-in-error and not-done Procedure resources', () {
      final jsonErr = jsonEncode({
        'resourceType': 'Procedure',
        'id': 'proc-err',
        'status': 'entered-in-error',
        'code': {'text': 'Erroneous Entry'},
      });
      final jsonNotDone = jsonEncode({
        'resourceType': 'Procedure',
        'id': 'proc-cancelled',
        'status': 'not-done',
        'code': {'text': 'Cancelled Surgery'},
      });

      expect(
        () => parser.parseJson(jsonErr, source: 'Portal'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parser.parseJson(jsonNotDone, source: 'Portal'),
        throwsA(isA<FormatException>()),
      );
    });

    test('parses Procedure within a multi-resource FHIR Bundle', () {
      final bundle = jsonEncode({
        'resourceType': 'Bundle',
        'type': 'searchset',
        'entry': [
          {
            'resource': {
              'resourceType': 'Procedure',
              'id': 'proc-knee',
              'status': 'completed',
              'code': {'text': 'Right Total Knee Arthroplasty'},
              'performedPeriod': {
                'start': '2024-03-20T08:00:00Z',
                'end': '2024-03-20T11:00:00Z',
              },
              'bodySite': [
                {'text': 'Right knee joint'},
              ],
            },
          },
          {
            'resource': {
              'resourceType': 'Condition',
              'id': 'cond-osteo',
              'code': {'text': 'Osteoarthritis of knee'},
            },
          },
        ],
      });

      final records = parser.parseJson(bundle, source: 'Orthopedic Clinic');
      expect(records, hasLength(2));

      final procRecord = records.firstWhere(
        (r) => r.category == RecordCategory.procedure,
      );
      expect(procRecord.name, 'Right Total Knee Arthroplasty');
      expect(procRecord.value, contains('Right knee joint'));
      expect(procRecord.recordedAt, DateTime.utc(2024, 3, 20, 8, 0));
    });

    test(
      'declares Procedure in FhirPortalImporter clinical resource types and scopes',
      () {
        expect(FhirPortalImporter.clinicalResourceTypes, contains('Procedure'));
        expect(FhirPortalImporter.clinicalResourceTypes, contains('Coverage'));
      },
    );

    test('FhirFilePreview recognizes Procedure resource type', () {
      final payload = FhirFilePayload(
        name: 'procedures.json',
        content: jsonEncode({
          'resourceType': 'Procedure',
          'id': 'proc-preview',
          'status': 'completed',
          'code': {'text': 'Colonoscopy'},
        }),
      );

      final preview = FhirFilePreview.fromPayload(payload);
      expect(preview.isValid, isTrue);
      expect(preview.records, hasLength(1));
      expect(preview.resourceCounts['Procedure'], 1);
    });

    test(
      'includes Procedures in doctor visit summary PDF generation',
      () async {
        final records = [
          HealthRecord(
            id: 'proc-cardio',
            name: 'Coronary Angiography and Stent Placement',
            value: 'Completed · Left anterior descending artery',
            unit: '',
            recordedAt: DateTime.utc(2025, 1, 10, 9, 0),
            category: RecordCategory.procedure,
            source: 'Cardiology Associates',
            status: 'completed',
          ),
        ];

        final exporter = HealthExportService();
        final doc = await exporter.buildDoctorVisitSummaryPdfDocument(records);
        final pdfBytes = await doc.save();
        expect(pdfBytes, isNotEmpty);
      },
    );
  });
}
