import 'dart:convert';

import 'package:clinical_assistant/exports/health_export_service.dart';
import 'package:clinical_assistant/integrations/fhir_file_import.dart';
import 'package:clinical_assistant/integrations/fhir_observation_parser.dart';
import 'package:clinical_assistant/integrations/fhir_portal_importer.dart';
import 'package:clinical_assistant/models/coverage_details.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = FhirObservationParser();

  group('FHIR Coverage Parsing & Ingestion', () {
    test(
      'parses full HL7 FHIR Coverage resource with policy details and copays',
      () {
        final json = jsonEncode({
          'resourceType': 'Coverage',
          'id': 'cov-9876',
          'status': 'active',
          'type': {
            'coding': [
              {
                'system': 'http://terminology.hl7.org/CodeSystem/v3-ActCode',
                'code': 'EHCPOL',
                'display': 'Extended healthcare',
              },
            ],
            'text': 'Comprehensive PPO',
          },
          'payor': [
            {
              'reference': 'Organization/bcbs-123',
              'display': 'Blue Cross Blue Shield of Massachusetts',
            },
          ],
          'subscriberId': 'SUB-987654321',
          'beneficiary': {'reference': 'Patient/p-42', 'display': 'Jane Doe'},
          'relationship': {
            'coding': [
              {'code': 'self', 'display': 'Self'},
            ],
          },
          'period': {'start': '2026-01-01', 'end': '2026-12-31'},
          'class': [
            {
              'type': {
                'coding': [
                  {
                    'system':
                        'http://terminology.hl7.org/CodeSystem/coverage-class',
                    'code': 'group',
                  },
                ],
              },
              'value': 'GRP-44021',
              'name': 'Acme Engineering Group Plan',
            },
            {
              'type': {
                'coding': [
                  {
                    'system':
                        'http://terminology.hl7.org/CodeSystem/coverage-class',
                    'code': 'plan',
                  },
                ],
              },
              'value': 'PPO-PLATINUM',
              'name': 'Preferred Gold PPO 500',
            },
          ],
          'network': 'National In-Network PPO',
          'costToBeneficiary': [
            {
              'type': {
                'coding': [
                  {'code': 'copay', 'display': 'Primary Care Copay'},
                ],
              },
              'valueMoney': {'value': 20.0, 'currency': 'USD'},
            },
            {
              'type': {
                'coding': [
                  {'code': 'copay', 'display': 'Specialist Copay'},
                ],
              },
              'valueMoney': {'value': 40.0, 'currency': 'USD'},
            },
          ],
          'note': [
            {'text': 'Preventive annual visits covered at 100%'},
          ],
        });

        final records = parser.parseJson(json, source: 'SMART Health Portal');
        expect(records, hasLength(1));

        final record = records.first;
        expect(record.category, RecordCategory.coverage);
        expect(record.name, 'Blue Cross Blue Shield of Massachusetts');
        expect(record.value, contains('Active'));
        expect(record.value, contains('Preferred Gold PPO 500'));
        expect(record.value, contains('Group: GRP-44021'));
        expect(record.source, 'SMART Health Portal');
        expect(record.code, 'EHCPOL');
        expect(record.status, 'active');
        expect(record.notes, 'Preventive annual visits covered at 100%');

        // Verify CoverageDetails extraction
        final details = CoverageDetails.fromRecord(record);
        expect(details, isNotNull);
        expect(details!.payorName, 'Blue Cross Blue Shield of Massachusetts');
        expect(details.subscriberId, 'SUB-987654321');
        expect(details.beneficiaryName, 'Jane Doe');
        expect(details.groupNumber, 'GRP-44021');
        expect(details.groupName, 'Acme Engineering Group Plan');
        expect(details.planName, 'Preferred Gold PPO 500');
        expect(details.network, 'National In-Network PPO');
        expect(details.periodStart, DateTime.utc(2026, 1, 1));
        expect(details.periodEnd, DateTime.utc(2026, 12, 31));
        expect(details.isActive, isTrue);
        expect(details.copays, hasLength(2));
        expect(details.copays[0].type, 'Primary Care Copay');
        expect(details.copays[0].amount, 'USD20.0');
        expect(details.copays[1].type, 'Specialist Copay');
        expect(details.copays[1].amount, 'USD40.0');
      },
    );

    test('ignores entered-in-error Coverage resource', () {
      final json = jsonEncode({
        'resourceType': 'Coverage',
        'id': 'cov-err',
        'status': 'entered-in-error',
        'payor': [
          {'display': 'Revoked Insurer'},
        ],
      });

      expect(
        () => parser.parseJson(json, source: 'Portal'),
        throwsA(isA<FormatException>()),
      );
    });

    test('parses Coverage in a multi-resource FHIR Bundle', () {
      final bundle = jsonEncode({
        'resourceType': 'Bundle',
        'type': 'searchset',
        'entry': [
          {
            'resource': {
              'resourceType': 'Coverage',
              'id': 'cov-bundle-1',
              'status': 'active',
              'payor': [
                {'display': 'Aetna Health'},
              ],
              'subscriberId': 'W123456789',
            },
          },
          {
            'resource': {
              'resourceType': 'Condition',
              'id': 'cond-bundle-1',
              'clinicalStatus': {
                'coding': [
                  {'code': 'active'},
                ],
              },
              'code': {'text': 'Hypertension'},
            },
          },
        ],
      });

      final records = parser.parseJson(bundle, source: 'Hospital System');
      expect(records, hasLength(2));

      final covRecord = records.firstWhere(
        (r) => r.category == RecordCategory.coverage,
      );
      expect(covRecord.name, 'Aetna Health');
      expect(covRecord.value, 'Active · ID: W123456789');

      final condRecord = records.firstWhere(
        (r) => r.category == RecordCategory.condition,
      );
      expect(condRecord.name, 'Hypertension');
    });

    test(
      'FhirFilePreview accurately counts and previews Coverage resources',
      () {
        final fhirPayload = FhirFilePayload(
          name: 'coverage_export.json',
          content: jsonEncode({
            'resourceType': 'Bundle',
            'entry': [
              {
                'resource': {
                  'resourceType': 'Coverage',
                  'id': 'c1',
                  'status': 'active',
                  'payor': [
                    {'display': 'UnitedHealthcare'},
                  ],
                },
              },
            ],
          }),
        );

        final summary = FhirFilesImportSummary.fromPayloads([fhirPayload]);
        expect(summary.totalFiles, 1);
        expect(summary.validFilesCount, 1);
        expect(summary.totalRecords, 1);
        expect(summary.aggregatedResourceCounts['Coverage'], 1);
      },
    );

    test(
      'FhirPortalImporter includes Coverage in clinical scopes and resource types',
      () {
        expect(FhirPortalImporter.clinicalResourceTypes, contains('Coverage'));
      },
    );

    test(
      'HealthExportService builds PDF doctor visit summary with Insurance & Coverage section',
      () async {
        final coverageRecord = HealthRecord(
          id: 'cov-test-1',
          name: 'UnitedHealthcare',
          value: 'Active · Choice Plus PPO · Group: UHC8899',
          unit: '',
          recordedAt: DateTime.utc(2026, 4, 1),
          category: RecordCategory.coverage,
          source: 'Health Plan Portal',
          sourceData: {
            'resourceType': 'Coverage',
            'id': 'cov-test-1',
            'status': 'active',
            'payor': [
              {'display': 'UnitedHealthcare'},
            ],
            'subscriberId': 'UHC-00112233',
            'class': [
              {
                'type': {
                  'coding': [
                    {'code': 'group'},
                  ],
                },
                'value': 'UHC8899',
              },
              {
                'type': {
                  'coding': [
                    {'code': 'plan'},
                  ],
                },
                'name': 'Choice Plus PPO',
              },
            ],
            'costToBeneficiary': [
              {
                'type': {
                  'coding': [
                    {'code': 'copay', 'display': 'Specialist'},
                  ],
                },
                'valueMoney': {'value': 35.0, 'currency': '\$'},
              },
            ],
          },
        );

        final exportService = HealthExportService();
        final pdfDoc = await exportService.buildDoctorVisitSummaryPdfDocument([
          coverageRecord,
        ]);
        final pdfBytes = await pdfDoc.save();

        expect(pdfBytes, isNotEmpty);
        expect(pdfBytes.length, greaterThan(500));
      },
    );
  });
}
