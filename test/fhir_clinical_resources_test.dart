import 'dart:convert';

import 'package:clinical_assistant/integrations/fhir_observation_parser.dart';
import 'package:clinical_assistant/integrations/fhir_portal_importer.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const parser = FhirObservationParser();

  group('FhirObservationParser clinical resources expansion', () {
    test(
      'parses MedicationRequest with dosage instruction, RxNorm code, and notes',
      () {
        final json = jsonEncode({
          'resourceType': 'MedicationRequest',
          'id': 'med-101',
          'status': 'active',
          'authoredOn': '2026-05-10T10:00:00Z',
          'medicationCodeableConcept': {
            'coding': [
              {
                'system': 'http://www.nlm.nih.gov/research/umls/rxnorm',
                'code': '866514',
                'display': 'Metformin hydrochloride 500 MG Oral Tablet',
              },
            ],
            'text': 'Metformin 500mg',
          },
          'dosageInstruction': [
            {'text': 'Take 1 tablet twice daily with meals'},
          ],
          'note': [
            {'text': 'Prescribed for glucose management'},
          ],
        });

        final records = parser.parseJson(json, source: 'Portal Clinic');
        expect(records, hasLength(1));
        final record = records.first;
        expect(record.category, RecordCategory.medication);
        expect(record.name, 'Metformin 500mg');
        expect(record.value, 'Take 1 tablet twice daily with meals');
        expect(record.code, '866514');
        expect(record.notes, 'Prescribed for glucose management');
        expect(record.source, 'Portal Clinic');
        expect(record.status, 'active');
      },
    );

    test(
      'parses MedicationStatement with reference fallback and reported status',
      () {
        final json = jsonEncode({
          'resourceType': 'MedicationStatement',
          'id': 'statement-202',
          'status': 'active',
          'effectiveDateTime': '2026-06-01T08:00:00Z',
          'medicationReference': {'display': 'Lisinopril 10 MG Oral Tablet'},
          'dosage': [
            {'text': '10 mg once daily in the morning'},
          ],
        });

        final records = parser.parseJson(json, source: 'Health System');
        expect(records, hasLength(1));
        final record = records.first;
        expect(record.category, RecordCategory.medication);
        expect(record.name, 'Lisinopril 10 MG Oral Tablet');
        expect(record.value, '10 mg once daily in the morning');
      },
    );

    test(
      'parses Condition with SNOMED coding, clinicalStatus, and severity',
      () {
        final json = jsonEncode({
          'resourceType': 'Condition',
          'id': 'cond-303',
          'clinicalStatus': {
            'coding': [
              {'code': 'active', 'display': 'Active'},
            ],
          },
          'verificationStatus': {
            'coding': [
              {'code': 'confirmed', 'display': 'Confirmed'},
            ],
          },
          'severity': {'text': 'Moderate'},
          'code': {
            'coding': [
              {
                'system': 'http://snomed.info/sct',
                'code': '38341003',
                'display': 'Hypertensive disorder',
              },
            ],
            'text': 'Essential hypertension',
          },
          'onsetDateTime': '2025-01-15',
          'note': [
            {'text': 'Controlled with lifestyle and medications'},
          ],
        });

        final records = parser.parseJson(json, source: 'Cardiology Clinic');
        expect(records, hasLength(1));
        final record = records.first;
        expect(record.category, RecordCategory.condition);
        expect(record.name, 'Essential hypertension');
        expect(record.value, 'Active (Moderate)');
        expect(record.code, '38341003');
        expect(record.notes, 'Controlled with lifestyle and medications');
        expect(record.recordedAt, DateTime.utc(2025, 1, 15));
      },
    );

    test('skips entered-in-error and refuted conditions', () {
      final bundle = {
        'resourceType': 'Bundle',
        'entry': [
          {
            'resource': {
              'resourceType': 'Condition',
              'id': 'err-1',
              'verificationStatus': {
                'coding': [
                  {'code': 'entered-in-error'},
                ],
              },
              'code': {'text': 'Misdiagnosed condition'},
              'recordedDate': '2026-01-01',
            },
          },
          {
            'resource': {
              'resourceType': 'Condition',
              'id': 'refuted-2',
              'verificationStatus': {
                'coding': [
                  {'code': 'refuted'},
                ],
              },
              'code': {'text': 'Refuted diagnosis'},
              'recordedDate': '2026-01-01',
            },
          },
        ],
      };

      final records = parser.parseBundle(bundle, source: 'Test');
      expect(records, isEmpty);
    });

    test(
      'parses AllergyIntolerance with reaction manifestations and criticality',
      () {
        final json = jsonEncode({
          'resourceType': 'AllergyIntolerance',
          'id': 'allergy-404',
          'clinicalStatus': {
            'coding': [
              {'code': 'active'},
            ],
          },
          'criticality': 'high',
          'code': {
            'coding': [
              {
                'system': 'http://snomed.info/sct',
                'code': '373270004',
                'display': 'Penicillin',
              },
            ],
            'text': 'Penicillin G',
          },
          'recordedDate': '2024-03-22T14:15:00Z',
          'reaction': [
            {
              'manifestation': [
                {'text': 'Anaphylaxis'},
                {'text': 'Urticaria'},
              ],
              'severity': 'severe',
            },
          ],
        });

        final records = parser.parseJson(json, source: 'Allergy Clinic');
        expect(records, hasLength(1));
        final record = records.first;
        expect(record.category, RecordCategory.allergy);
        expect(record.name, 'Penicillin G');
        expect(record.value, 'Anaphylaxis, Urticaria (severe)');
        expect(record.code, '373270004');
      },
    );

    test('parses Immunization with vaccine CVX code and lot number', () {
      final json = jsonEncode({
        'resourceType': 'Immunization',
        'id': 'imm-505',
        'status': 'completed',
        'vaccineCode': {
          'coding': [
            {
              'system': 'http://hl7.org/fhir/sid/cvx',
              'code': '208',
              'display': 'COVID-19, mRNA, LNP-S, PF, 30 mcg/0.3 mL dose',
            },
          ],
          'text': 'COVID-19 mRNA Vaccine',
        },
        'occurrenceDateTime': '2025-10-12T16:00:00Z',
        'lotNumber': 'EP2198',
        'note': [
          {'text': 'Booster dose administered in left deltoid'},
        ],
      });

      final records = parser.parseJson(json, source: 'Pharmacy');
      expect(records, hasLength(1));
      final record = records.first;
      expect(record.category, RecordCategory.immunization);
      expect(record.name, 'COVID-19 mRNA Vaccine');
      expect(record.value, 'Completed (Lot: EP2198)');
      expect(record.code, '208');
      expect(record.notes, 'Booster dose administered in left deltoid');
    });

    test(
      'parses comprehensive bundle with observations, medications, conditions, allergies, and immunizations',
      () {
        final bundle = {
          'resourceType': 'Bundle',
          'entry': [
            {
              'resource': {
                'resourceType': 'Observation',
                'id': 'obs-1',
                'status': 'final',
                'code': {'text': 'Hemoglobin A1c'},
                'valueQuantity': {'value': 5.8, 'unit': '%'},
                'effectiveDateTime': '2026-08-01T10:00:00Z',
              },
            },
            {
              'resource': {
                'resourceType': 'MedicationRequest',
                'id': 'med-1',
                'status': 'active',
                'code': {'text': 'Atorvastatin 20mg'},
                'authoredOn': '2026-08-01T10:05:00Z',
                'dosageInstruction': [
                  {'text': 'Take 1 tablet daily at bedtime'},
                ],
              },
            },
            {
              'resource': {
                'resourceType': 'Condition',
                'id': 'cond-1',
                'clinicalStatus': {'text': 'Active'},
                'code': {'text': 'Hyperlipidemia'},
                'recordedDate': '2026-08-01T10:10:00Z',
              },
            },
            {
              'resource': {
                'resourceType': 'AllergyIntolerance',
                'id': 'all-1',
                'clinicalStatus': {'text': 'Active'},
                'code': {'text': 'Latex'},
                'recordedDate': '2026-08-01T10:15:00Z',
              },
            },
            {
              'resource': {
                'resourceType': 'Immunization',
                'id': 'imm-1',
                'status': 'completed',
                'vaccineCode': {'text': 'Influenza seasonal'},
                'occurrenceDateTime': '2026-08-01T10:20:00Z',
              },
            },
          ],
        };

        final records = parser.parseBundle(bundle, source: 'Memorial Hospital');
        expect(records, hasLength(5));
        final categories = records.map((r) => r.category).toSet();
        expect(categories, contains(RecordCategory.lab));
        expect(categories, contains(RecordCategory.medication));
        expect(categories, contains(RecordCategory.condition));
        expect(categories, contains(RecordCategory.allergy));
        expect(categories, contains(RecordCategory.immunization));
      },
    );
  });

  group('FhirPortalImporter multi-resource syncing', () {
    test(
      'gracefully continues when an optional clinical resource endpoint returns 404 or 403',
      () async {
        final requestedPaths = <String>[];
        final importer = FhirPortalImporter(
          appAuth: _FakeAppAuth(),
          client: MockClient((request) async {
            final path = request.url.path;
            requestedPaths.add(path);
            if (path.endsWith('/.well-known/smart-configuration')) {
              return http.Response(
                jsonEncode({
                  'authorization_endpoint': 'https://auth.example/authorize',
                  'token_endpoint': 'https://auth.example/token',
                }),
                200,
              );
            }
            if (path.endsWith('/Observation')) {
              return http.Response(
                jsonEncode({
                  'resourceType': 'Bundle',
                  'entry': [
                    {
                      'resource': {
                        'resourceType': 'Observation',
                        'id': 'lab-10',
                        'status': 'final',
                        'code': {'text': 'Potassium'},
                        'effectiveDateTime': '2026-09-01T00:00:00Z',
                        'valueQuantity': {'value': 4.2, 'unit': 'mmol/L'},
                      },
                    },
                  ],
                }),
                200,
              );
            }
            if (path.endsWith('/MedicationRequest')) {
              // Server does not support MedicationRequest (404)
              return http.Response(
                '{"resourceType": "OperationOutcome", "issue": []}',
                404,
              );
            }
            if (path.endsWith('/Condition')) {
              // User does not have condition read permissions (403)
              return http.Response('Forbidden', 403);
            }
            if (path.endsWith('/AllergyIntolerance')) {
              return http.Response(
                jsonEncode({
                  'resourceType': 'Bundle',
                  'entry': [
                    {
                      'resource': {
                        'resourceType': 'AllergyIntolerance',
                        'id': 'allergy-10',
                        'code': {'text': 'Sulfa'},
                        'clinicalStatus': {'text': 'Active'},
                        'recordedDate': '2026-09-01T00:00:00Z',
                      },
                    },
                  ],
                }),
                200,
              );
            }
            if (path.endsWith('/Immunization')) {
              return http.Response('Not Implemented', 501);
            }
            return http.Response('Not Found', 404);
          }),
        );

        final result = await importer.refreshAndImportLabResults(
          fhirBaseUrl: 'https://fhir.example/api',
          clientId: 'client-1',
          patientId: 'patient-99',
          refreshToken: 'refresh-token',
          authorizationEndpoint: 'https://auth.example/authorize',
          tokenEndpoint: 'https://auth.example/token',
          since: DateTime.utc(2026, 1, 1),
          resourceTypes: FhirPortalImporter.clinicalResourceTypes,
          onRefreshTokenUpdated: (_) async {},
        );

        expect(result.records, hasLength(2));
        final names = result.records.map((r) => r.name).toList();
        expect(names, contains('Potassium'));
        expect(names, contains('Sulfa'));
      },
    );
  });
}

class _FakeAppAuth extends FlutterAppAuth {
  @override
  Future<TokenResponse> token(TokenRequest request) async {
    return TokenResponse(
      'refreshed-token',
      'refreshed-token',
      null,
      null,
      'Bearer',
      null,
      null,
    );
  }
}
