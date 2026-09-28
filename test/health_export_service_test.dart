import 'dart:convert';

import 'package:clinical_assistant/exports/health_export_service.dart';
import 'package:clinical_assistant/exports/export_selection.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final exporter = HealthExportService();
  final record = HealthRecord(
    id: 'fhir:observation-1',
    name: 'Glucose',
    value: '96',
    unit: 'mg/dL',
    recordedAt: DateTime.utc(2026, 9, 20, 14, 30),
    category: RecordCategory.lab,
    source: 'portal.example',
    code: '2345-7',
    referenceRange: '70-99 mg/dL',
    status: 'final',
    sourceData: const {
      'resourceType': 'Observation',
      'id': 'observation-1',
      'status': 'final',
    },
  );

  test('preserves imported FHIR resources in the exported Bundle', () {
    final bundle = exporter.buildFhirBundle([record]);

    expect(bundle['resourceType'], 'Bundle');
    final entry = (bundle['entry']! as List).single as Map;
    expect(entry['resource'], record.sourceData);
  });

  test('encodes CSV values and includes source and reference range', () {
    final csv = exporter.buildCsv([record]);

    expect(csv, contains('Recorded at (UTC)'));
    expect(csv, contains('Source data (JSON)'));
    expect(csv, contains('Glucose,96,mg/dL'));
    expect(csv, contains('portal.example'));
    expect(csv, contains('70-99 mg/dL'));
  });

  test('exports only records from selected categories', () {
    final activity = HealthRecord(
      id: 'health:steps',
      name: 'Steps',
      value: '6400',
      unit: 'count',
      recordedAt: DateTime.utc(2026, 9, 20),
      category: RecordCategory.activity,
      source: 'Health Connect',
    );
    final selected = selectRecordsForExport(
      [record, activity],
      {RecordCategory.lab},
    );

    expect(selected, [record]);
    final csv = exporter.buildCsv(selected);
    expect(csv, contains('Glucose,96,mg/dL'));
    expect(csv, isNot(contains('Steps')));
    expect(csv, isNot(contains('6400')));
    expect(
      (exporter.buildFhirBundle(selected)['entry']! as List),
      hasLength(1),
    );
  });

  test('encodes non-FHIR records as honest FHIR Observations', () {
    final bundle = exporter.buildFhirBundle([
      HealthRecord(
        id: 'health:apple:123',
        name: 'Heart rate',
        value: '72',
        unit: 'BEATS_PER_MINUTE',
        recordedAt: DateTime.utc(2026, 9, 20),
        category: RecordCategory.vital,
        source: 'Apple Health',
      ),
    ]);

    final observation =
        ((bundle['entry']! as List).single as Map)['resource'] as Map;
    expect(observation['resourceType'], 'Observation');
    expect(observation['status'], 'unknown');
    expect((observation['valueQuantity'] as Map)['value'], 72);
    expect(observation['effectiveDateTime'], '2026-09-20T00:00:00.000Z');
  });

  test('preserves structured platform data in FHIR and CSV exports', () {
    final structured = HealthRecord(
      id: 'health:source:route-1',
      name: 'Workout route',
      value: 'Workout route · 1 location samples',
      unit: '',
      recordedAt: DateTime.utc(2026, 9, 20),
      category: RecordCategory.activity,
      source: 'Health Connect',
      code: 'WORKOUT_ROUTE',
      sourceData: const {
        'type': 'WORKOUT_ROUTE',
        'value': {
          'locations': [
            {'latitude': 37.3, 'longitude': -122.0},
          ],
        },
      },
    );

    final bundle = exporter.buildFhirBundle([structured]);
    final observation =
        ((bundle['entry']! as List).single as Map)['resource'] as Map;
    final extensions = observation['extension'] as List;
    final sourceExtension = extensions.single as Map;
    final csv = exporter.buildCsv([structured]);

    expect(observation['resourceType'], 'Observation');
    expect((observation['category'] as List).single['text'], 'Activity');
    final fhirSourceData =
        jsonDecode(sourceExtension['valueString'] as String) as Map;
    expect((fhirSourceData['value'] as Map)['locations'], isNotEmpty);
    expect(csv, contains('longitude'));
    expect(csv, contains('37.3'));
  });
}
