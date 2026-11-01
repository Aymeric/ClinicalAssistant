import 'package:clinical_assistant/integrations/apple_clinical_records_importer.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/apple_clinical_records');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'parses HealthKit lab resources and preserves clinical provenance',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'importLabRecords');
            return [
              {
                'sourceId': 'org.example.hospital',
                'sourceName': 'Example Hospital',
                'resource': {
                  'resourceType': 'Observation',
                  'id': 'lab-1',
                  'status': 'final',
                  'code': {'text': 'Glucose'},
                  'effectiveDateTime': '2026-09-20T14:30:00Z',
                  'valueQuantity': {'value': 96, 'unit': 'mg/dL'},
                },
              },
            ];
          });

      final records = await AppleClinicalRecordsImporter(
        channel: channel,
      ).importLabRecords();

      expect(records, hasLength(1));
      expect(records.single.id, 'health-clinical:org.example.hospital:lab-1');
      expect(records.single.name, 'Glucose');
      expect(records.single.displayValue, '96 mg/dL');
      expect(records.single.source, 'Apple Health (Example Hospital)');
      expect(records.single.sourceId, 'org.example.hospital');
      expect(records.single.sourceData?['resourceType'], 'Observation');
    },
  );
  test('includes historical observations for later sync discovery', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return [
            for (final date in ['2025-12-31', '2026-01-01'])
              {
                'sourceId': 'org.example.hospital',
                'sourceName': 'Example Hospital',
                'resource': {
                  'resourceType': 'Observation',
                  'id': date,
                  'status': 'final',
                  'code': {'text': 'Glucose'},
                  'effectiveDateTime': '${date}T14:30:00Z',
                  'valueQuantity': {'value': 96, 'unit': 'mg/dL'},
                },
              },
          ];
        });

    final records = await AppleClinicalRecordsImporter(
      channel: channel,
    ).importLabRecords(timeout: const Duration(milliseconds: 5));

    expect(records, hasLength(2));
    expect(records.map((record) => record.sourceData?['id']), [
      '2025-12-31',
      '2026-01-01',
    ]);
  });

  test(
    'rejects malformed native responses instead of silently dropping data',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => ['not a record']);

      await expectLater(
        AppleClinicalRecordsImporter(channel: channel).importLabRecords(),
        throwsFormatException,
      );
    },
  );

  test('returns empty list when platform call times out', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return [];
        });

    final records = await AppleClinicalRecordsImporter(
      channel: channel,
    ).importLabRecords();

    expect(records, isEmpty);
  });

  test('returns empty list when PlatformException is thrown', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(
            code: 'UNAVAILABLE',
            message: 'HealthKit unavailable',
          );
        });

    final records = await AppleClinicalRecordsImporter(
      channel: channel,
    ).importLabRecords();

    expect(records, isEmpty);
  });

  test('returns empty list when MissingPluginException is thrown', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw MissingPluginException();
        });

    final records = await AppleClinicalRecordsImporter(
      channel: channel,
    ).importLabRecords();

    expect(records, isEmpty);
  });

  test(
    'extracts standalone DiagnosticReport resources with narrative text or conclusion',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            return [
              {
                'sourceId': 'com.apple.Health',
                'sourceName': 'Metro Radiology',
                'resource': {
                  'resourceType': 'DiagnosticReport',
                  'id': 'rad-100',
                  'status': 'final',
                  'code': {'text': 'Chest X-Ray'},
                  'effectiveDateTime': '2026-10-22T11:00:00Z',
                  'performer': [
                    {'display': 'Metro Imaging Specialist'},
                  ],
                  'text': {
                    'status': 'generated',
                    'div':
                        '<div xmlns="http://www.w3.org/1999/xhtml"><p>Clear bilateral lung fields. Normal cardiac size.</p></div>',
                  },
                },
              },
            ];
          });

      final records = await AppleClinicalRecordsImporter(
        channel: channel,
      ).importLabRecords();

      expect(records, hasLength(1));
      final report = records.first;
      expect(report.id, 'health-clinical:com.apple.Health:rad-100');
      expect(report.name, 'Chest X-Ray');
      expect(report.value, 'Clear bilateral lung fields. Normal cardiac size.');
      expect(report.source, 'Apple Health (Metro Radiology)');
      expect(report.sourceData?['panel'], isNotNull);
      final panel = report.sourceData!['panel'] as Map;
      expect(panel['performer'], 'Metro Imaging Specialist');
    },
  );

  test(
    'bundles DiagnosticReport with child observations for panel linkage and timestamp inheritance',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            return [
              {
                'sourceId': 'com.epic.mychart',
                'sourceName': 'General Hospital',
                'resource': {
                  'resourceType': 'DiagnosticReport',
                  'id': 'dr-lipid-1',
                  'status': 'final',
                  'code': {
                    'coding': [
                      {'code': '57698-3', 'display': 'Lipid Panel'},
                    ],
                    'text': 'Lipid Panel',
                  },
                  'effectiveDateTime': '2026-10-24T08:00:00Z',
                  'performer': [
                    {'display': 'Hospital Pathology Laboratory'},
                  ],
                  'conclusion': 'Lipids are within target limits.',
                  'result': [
                    {'reference': 'Observation/obs-chol'},
                    {'reference': 'Observation/obs-trig'},
                  ],
                },
              },
              {
                'sourceId': 'com.epic.mychart',
                'sourceName': 'General Hospital',
                'resource': {
                  'resourceType': 'Observation',
                  'id': 'obs-chol',
                  'status': 'final',
                  'code': {'text': 'Total Cholesterol'},
                  'valueQuantity': {'value': 175, 'unit': 'mg/dL'},
                  // Note: omitting effectiveDateTime to verify fallback inheritance from DiagnosticReport
                },
              },
              {
                'sourceId': 'com.epic.mychart',
                'sourceName': 'General Hospital',
                'resource': {
                  'resourceType': 'Observation',
                  'id': 'obs-trig',
                  'status': 'final',
                  'code': {'text': 'Triglycerides'},
                  'valueQuantity': {'value': 110, 'unit': 'mg/dL'},
                  'effectiveDateTime': '2026-10-24T08:00:00Z',
                },
              },
            ];
          });

      final records = await AppleClinicalRecordsImporter(
        channel: channel,
      ).importLabRecords();

      expect(records, hasLength(2));
      final chol = records.firstWhere((r) => r.name == 'Total Cholesterol');
      final trig = records.firstWhere((r) => r.name == 'Triglycerides');

      expect(chol.value, '175');
      expect(chol.recordedAt, DateTime.parse('2026-10-24T08:00:00Z'));
      expect(chol.sourceData?['panel'], isNotNull);
      final cholPanel = chol.sourceData!['panel'] as Map;
      expect(cholPanel['name'], 'Lipid Panel');
      expect(cholPanel['code'], '57698-3');
      expect(cholPanel['performer'], 'Hospital Pathology Laboratory');
      expect(cholPanel['conclusion'], 'Lipids are within target limits.');

      expect(trig.sourceData?['panel'], isNotNull);
      final trigPanel = trig.sourceData!['panel'] as Map;
      expect(trigPanel['id'], 'dr-lipid-1');
    },
  );

  test(
    'ingests conditions, medications, allergies, and immunizations from Apple Health',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            return [
              {
                'sourceId': 'com.epic.mychart',
                'sourceName': 'St. Jude Hospital',
                'resource': {
                  'resourceType': 'Condition',
                  'id': 'cond-htn',
                  'clinicalStatus': {
                    'coding': [
                      {'code': 'active'},
                    ],
                  },
                  'code': {'text': 'Essential Hypertension'},
                  'onsetDateTime': '2025-05-10T09:00:00Z',
                },
              },
              {
                'sourceId': 'com.epic.mychart',
                'sourceName': 'St. Jude Hospital',
                'resource': {
                  'resourceType': 'MedicationRequest',
                  'id': 'med-lisinopril',
                  'status': 'active',
                  'medicationCodeableConcept': {
                    'text': 'Lisinopril 10 MG Oral Tablet',
                  },
                  'authoredOn': '2026-01-15T10:00:00Z',
                },
              },
              {
                'sourceId': 'com.epic.mychart',
                'sourceName': 'St. Jude Hospital',
                'resource': {
                  'resourceType': 'AllergyIntolerance',
                  'id': 'allergy-penicillin',
                  'clinicalStatus': {
                    'coding': [
                      {'code': 'active'},
                    ],
                  },
                  'code': {'text': 'Penicillin'},
                  'recordedDate': '2024-03-20T12:00:00Z',
                },
              },
              {
                'sourceId': 'com.epic.mychart',
                'sourceName': 'St. Jude Hospital',
                'resource': {
                  'resourceType': 'Immunization',
                  'id': 'imm-flu',
                  'status': 'completed',
                  'vaccineCode': {'text': 'Influenza seasonal'},
                  'occurrenceDateTime': '2026-10-01T14:00:00Z',
                },
              },
            ];
          });

      final records = await AppleClinicalRecordsImporter(
        channel: channel,
      ).importLabRecords();

      expect(records, hasLength(4));

      final condition = records.firstWhere(
        (r) => r.name == 'Essential Hypertension',
      );
      expect(condition.category, RecordCategory.condition);
      expect(condition.value, 'Active');

      final medication = records.firstWhere(
        (r) => r.name.contains('Lisinopril'),
      );
      expect(medication.category, RecordCategory.medication);

      final allergy = records.firstWhere((r) => r.name == 'Penicillin');
      expect(allergy.category, RecordCategory.allergy);

      final immunization = records.firstWhere(
        (r) => r.name.contains('Influenza'),
      );
      expect(immunization.category, RecordCategory.immunization);
    },
  );
}
