import 'package:clinical_assistant/integrations/fhir_observation_parser.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = FhirObservationParser();

  test(
    'parses FHIR laboratory results and panel components with provenance',
    () {
      final records = parser.parseBundle({
        'resourceType': 'Bundle',
        'entry': [
          {
            'resource': {
              'resourceType': 'Observation',
              'id': 'glucose-1',
              'status': 'final',
              'code': {
                'coding': [
                  {
                    'system': 'http://loinc.org',
                    'code': '2345-7',
                    'display': 'Glucose',
                  },
                ],
              },
              'effectiveDateTime': '2026-09-20T14:30:00Z',
              'valueQuantity': {
                'value': 96,
                'unit': 'mg/dL',
                'system': 'http://unitsofmeasure.org',
                'code': 'mg/dL',
              },
              'referenceRange': [
                {
                  'low': {'value': 70, 'unit': 'mg/dL'},
                  'high': {'value': 99, 'unit': 'mg/dL'},
                },
              ],
              'component': [
                {
                  'code': {
                    'coding': [
                      {'display': 'Fasting glucose'},
                    ],
                  },
                  'valueQuantity': {'value': 96, 'unit': 'mg/dL'},
                },
              ],
            },
          },
        ],
      }, source: 'portal.example');

      expect(records, hasLength(2));
      expect(records.first.category, RecordCategory.lab);
      expect(records.first.name, 'Glucose');
      expect(records.first.displayValue, '96 mg/dL');
      expect(records.first.referenceRange, '70–99 mg/dL');
      expect(records.first.sourceData?['resourceType'], 'Observation');
      expect(records.last.name, 'Fasting glucose');
      expect(records.last.sourceId, 'portal.example');
    },
  );

  test('skips cancelled and entered-in-error observations', () {
    final records = parser.parseBundle({
      'resourceType': 'Bundle',
      'entry': [
        for (final status in ['cancelled', 'entered-in-error'])
          {
            'resource': {
              'resourceType': 'Observation',
              'id': status,
              'status': status,
              'code': {'text': 'Glucose'},
              'effectiveDateTime': '2026-09-20T14:30:00Z',
              'valueQuantity': {'value': 96, 'unit': 'mg/dL'},
            },
          },
      ],
    }, source: 'portal.example');

    expect(records, isEmpty);
  });

  test('rejects a non-Bundle provider response', () {
    expect(
      () =>
          parser.parseBundle({'resourceType': 'Observation'}, source: 'portal'),
      throwsFormatException,
    );
  });

  test('keeps equal resource IDs from separate portal bases distinct', () {
    const observation = {
      'resourceType': 'Bundle',
      'entry': [
        {
          'resource': {
            'resourceType': 'Observation',
            'id': 'result-1',
            'status': 'final',
            'code': {'text': 'Glucose'},
            'effectiveDateTime': '2026-09-20T14:30:00Z',
            'valueQuantity': {'value': 96, 'unit': 'mg/dL'},
          },
        },
      ],
    };

    final first = parser
        .parseBundle(
          observation,
          source: 'portal.example',
          sourceId: 'https://portal.example/hospital-a/fhir/',
        )
        .single;
    final second = parser
        .parseBundle(
          observation,
          source: 'portal.example',
          sourceId: 'https://portal.example/hospital-b/fhir/',
        )
        .single;

    expect(first.id, isNot(second.id));
    expect(first.sourceId, 'https://portal.example/hospital-a/fhir/');
  });
}
