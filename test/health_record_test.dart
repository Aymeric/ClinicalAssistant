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

  test('handles notes serialization, copyWith, and isManual', () {
    final record = HealthRecord(
      id: 'manual-1',
      name: 'Blood Pressure',
      value: '120/80',
      unit: 'mmHg',
      recordedAt: DateTime.utc(2026, 9, 21, 8, 0),
      category: RecordCategory.vital,
      source: 'Manual Entry',
      notes: 'Morning measurement before coffee',
    );

    expect(record.isManual, isTrue);
    expect(record.notes, 'Morning measurement before coffee');

    final json = record.toJson();
    expect(json['notes'], 'Morning measurement before coffee');

    final restored = HealthRecord.fromJson(json);
    expect(restored.notes, 'Morning measurement before coffee');

    final updated = record.copyWith(notes: 'Updated note');
    expect(updated.notes, 'Updated note');
    expect(updated.name, record.name);
  });

  test('backward compatibility: handles JSON without notes field', () {
    final legacyJson = <String, Object?>{
      'id': 'rec-1',
      'name': 'Heart Rate',
      'value': '72',
      'unit': 'bpm',
      'recordedAt': '2026-09-20T10:00:00.000Z',
      'category': 'vital',
      'source': 'Apple Health',
    };

    final record = HealthRecord.fromJson(legacyJson);
    expect(record.notes, isNull);
    expect(record.isManual, isFalse);
    expect(record.toJson().containsKey('notes'), isFalse);
  });

  test('serializes and deserializes all RecordCategory values faithfully', () {
    for (final cat in RecordCategory.values) {
      final record = HealthRecord(
        id: 'cat-${cat.name}',
        name: 'Record in ${cat.name}',
        value: 'Normal',
        unit: '',
        recordedAt: DateTime.utc(2026, 9, 28, 12, 0),
        category: cat,
        source: 'Test Provider',
      );

      final json = record.toJson();
      expect(json['category'], cat.name);

      final restored = HealthRecord.fromJson(json);
      expect(restored.category, cat);
    }
  });

  group('measurementContext optimization and resolution edge cases', () {
    test('extracts context accurately when notes contain context: tag', () {
      final record1 = HealthRecord(
        id: 'ctx-1',
        name: 'Glucose',
        value: '95',
        unit: 'mg/dL',
        recordedAt: DateTime.utc(2026, 9, 28),
        category: RecordCategory.lab,
        source: 'Manual Entry',
        notes: 'context: Fasting',
      );
      expect(record1.measurementContext, 'Fasting');
      expect(record1.hasExplicitMeasurementContext, isTrue);

      final record2 = HealthRecord(
        id: 'ctx-2',
        name: 'Glucose',
        value: '135',
        unit: 'mg/dL',
        recordedAt: DateTime.utc(2026, 9, 28),
        category: RecordCategory.lab,
        source: 'Manual Entry',
        notes: 'Pre-check\nContext: Post-meal (2 hr)\nNote: Feeling good',
      );
      expect(record2.measurementContext, 'Post-meal (2 hr)');
      expect(record2.hasExplicitMeasurementContext, isTrue);
    });

    test('defaults to Unspecified when notes do not contain context tag', () {
      final record = HealthRecord(
        id: 'ctx-3',
        name: 'Blood Pressure',
        value: '120/80',
        unit: 'mmHg',
        recordedAt: DateTime.utc(2026, 9, 28),
        category: RecordCategory.vital,
        source: 'Manual Entry',
        notes: 'Routine evening checkup after walk',
      );
      expect(record.measurementContext, 'Unspecified');
      expect(record.hasExplicitMeasurementContext, isFalse);
    });
  });
}
