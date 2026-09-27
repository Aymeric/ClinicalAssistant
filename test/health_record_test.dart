import 'package:clinical_assistant/models/health_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips a record and its original FHIR resource', () {
    final resource = <String, Object?>{
      'resourceType': 'Observation',
      'id': 'lab-42',
      'component': [
        {'code': 'potassium'},
      ],
    };
    final original = HealthRecord(
      id: 'fhir:lab-42',
      name: 'Potassium',
      value: '4.1',
      unit: 'mmol/L',
      recordedAt: DateTime.utc(2026, 9, 20, 15, 30),
      category: RecordCategory.lab,
      source: 'portal.example',
      sourceId: 'https://portal.example/fhir/',
      code: '2823-3',
      referenceRange: '3.5-5.1 mmol/L',
      status: 'final',
      sourceData: resource,
    );

    final restored = HealthRecord.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.displayValue, '4.1 mmol/L');
    expect(restored.recordedAt, original.recordedAt);
    expect(restored.sourceData, resource);
    expect(restored.sourceId, original.sourceId);
  });
}
