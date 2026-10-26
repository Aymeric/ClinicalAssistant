import 'dart:convert';
import 'dart:io';

import 'package:clinical_assistant/controllers/health_data_controller.dart';
import 'package:clinical_assistant/data/encrypted_record_store.dart';
import 'package:clinical_assistant/integrations/fhir_file_import.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/sync/foreground_sync_state.dart';
import 'package:clinical_assistant/sync/import_progress.dart';
import 'package:clinical_assistant/sync/source_import_history.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryRecordStore extends EncryptedRecordStore {
  _MemoryRecordStore() : super(directory: Directory.systemTemp);

  List<HealthRecord> records = const [];

  @override
  Future<List<HealthRecord>> load() async => records;

  @override
  Future<void> save(
    List<HealthRecord> records, {
    ImportProgressCallback? onProgress,
  }) async {
    this.records = records;
  }

  @override
  Future<void> clear() async {
    records = const [];
  }
}

class _MemorySyncValueStore implements SyncValueStore {
  final Map<String, String> _values = {};

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

String _observationBundle(
  String id,
  String testName,
  double value,
  String unit,
) {
  return jsonEncode({
    'resourceType': 'Bundle',
    'id': 'bundle-$id',
    'type': 'collection',
    'entry': [
      {
        'resource': {
          'resourceType': 'Observation',
          'id': id,
          'status': 'final',
          'code': {
            'coding': [
              {
                'system': 'http://loinc.org',
                'code': '1558-6',
                'display': testName,
              },
            ],
            'text': testName,
          },
          'subject': {'reference': 'Patient/p1'},
          'effectiveDateTime': '2026-03-15T08:30:00Z',
          'valueQuantity': {
            'value': value,
            'unit': unit,
            'system': 'http://unitsofmeasure.org',
            'code': unit,
          },
        },
      },
    ],
  });
}

String _medicationBundle(String id, String medName) {
  return jsonEncode({
    'resourceType': 'Bundle',
    'id': 'med-bundle-$id',
    'type': 'collection',
    'entry': [
      {
        'resource': {
          'resourceType': 'MedicationStatement',
          'id': id,
          'status': 'active',
          'medicationCodeableConcept': {'text': medName},
          'subject': {'reference': 'Patient/p1'},
          'effectiveDateTime': '2026-03-10T12:00:00Z',
        },
      },
    ],
  });
}

void main() {
  group('FhirFilePayload & FhirFilePreview', () {
    test('parses clean FHIR bundle and tallies resource types', () {
      final json = _observationBundle('obs-1', 'Glucose', 95.0, 'mg/dL');
      const payload = FhirFilePayload(
        name: 'labs_2026.json',
        content: '',
        sizeInBytes: 1536,
      );
      final preview = FhirFilePreview.fromPayload(
        FhirFilePayload(
          name: payload.name,
          content: json,
          sizeInBytes: payload.sizeInBytes,
        ),
      );

      expect(preview.isValid, isTrue);
      expect(preview.error, isNull);
      expect(preview.records.length, 1);
      expect(preview.records.first.name, 'Glucose');
      expect(preview.records.first.value, '95');
      expect(preview.resourceCounts['Observation'], 1);
      expect(preview.formattedSize, '1.5 KB');
    });

    test('flags malformed JSON file with readable error', () {
      const payload = FhirFilePayload(
        name: 'corrupted.json',
        content: '{ "resourceType": "Bundle", invalid-json }',
      );
      final preview = FhirFilePreview.fromPayload(payload);

      expect(preview.isValid, isFalse);
      expect(preview.records, isEmpty);
      expect(preview.error, isNotNull);
      expect(preview.error, contains('Unexpected character'));
    });

    test('flags file with unsupported resources or empty content', () {
      const emptyPayload = FhirFilePayload(name: 'empty.json', content: '  ');
      final emptyPreview = FhirFilePreview.fromPayload(emptyPayload);
      expect(emptyPreview.isValid, isFalse);
      expect(emptyPreview.error, contains('File is empty'));

      final nonFhirPayload = FhirFilePayload(
        name: 'other.json',
        content: jsonEncode({'resourceType': 'Device', 'id': 'd1'}),
      );
      final nonFhirPreview = FhirFilePreview.fromPayload(nonFhirPayload);
      expect(nonFhirPreview.isValid, isFalse);
      expect(
        nonFhirPreview.error,
        contains('not a recognized FHIR Bundle or clinical resource'),
      );
    });
  });

  group('FhirFilesImportSummary', () {
    test('aggregates counts and resources across multiple valid files', () {
      final file1 = FhirFilePayload(
        name: 'labs.json',
        content: _observationBundle('obs-1', 'Fasting Glucose', 92.0, 'mg/dL'),
        sizeInBytes: 800,
      );
      final file2 = FhirFilePayload(
        name: 'meds.json',
        content: _medicationBundle('med-1', 'Metformin 500mg'),
        sizeInBytes: 1200,
      );

      final summary = FhirFilesImportSummary.fromPayloads([file1, file2]);

      expect(summary.totalFiles, 2);
      expect(summary.validFilesCount, 2);
      expect(summary.hasErrors, isFalse);
      expect(summary.totalRecords, 2);
      expect(summary.allValidRecords.length, 2);
      expect(summary.aggregatedResourceCounts['Observation'], 1);
      expect(summary.aggregatedResourceCounts['MedicationStatement'], 1);
    });

    test('identifies batch error when at least one file is invalid', () {
      final valid = FhirFilePayload(
        name: 'labs.json',
        content: _observationBundle('obs-1', 'Glucose', 90.0, 'mg/dL'),
      );
      const invalid = FhirFilePayload(
        name: 'broken.json',
        content: '{not valid}',
      );

      final summary = FhirFilesImportSummary.fromPayloads([valid, invalid]);

      expect(summary.totalFiles, 2);
      expect(summary.validFilesCount, 1);
      expect(summary.hasErrors, isTrue);
    });
  });

  group('HealthDataController.importFhirFiles', () {
    late _MemoryRecordStore store;
    late HealthDataController controller;

    setUp(() {
      store = _MemoryRecordStore();
      controller = HealthDataController(
        store: store,
        syncValueStore: _MemorySyncValueStore(),
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('imports multiple valid files and records source outcome', () async {
      final file1 = FhirFilePayload(
        name: 'hospital_labs.json',
        content: _observationBundle('obs-10', 'Cholesterol', 190.0, 'mg/dL'),
      );
      final file2 = FhirFilePayload(
        name: 'clinic_meds.json',
        content: _medicationBundle('med-20', 'Atorvastatin 20mg'),
      );

      final imported = await controller.importFhirFiles([
        file1,
        file2,
      ], customSourceLabel: 'Hospital Records 2026');

      expect(imported.length, 2);
      expect(controller.records.length, 2);
      expect(
        controller.records.any(
          (r) => r.name == 'Cholesterol' && r.source == 'Hospital Records 2026',
        ),
        isTrue,
      );
      expect(
        controller.records.any(
          (r) =>
              r.name == 'Atorvastatin 20mg' &&
              r.source == 'Hospital Records 2026',
        ),
        isTrue,
      );

      // Verify history
      expect(controller.importHistory, isNotEmpty);
      final latest = controller.importHistory.first;
      expect(latest.sourceKind, SourceImportSourceKind.fhirJson);
      expect(latest.sourceLabel, 'Hospital Records 2026');
      expect(latest.status, SourceImportOutcomeStatus.succeeded);
      expect(latest.fetchedCount, 2);
      expect(latest.addedCount, 2);
    });

    test(
      'enforces atomic validation: aborts before saving if any file is invalid',
      () async {
        final valid = FhirFilePayload(
          name: 'valid_labs.json',
          content: _observationBundle('obs-99', 'Potassium', 4.2, 'mmol/L'),
        );
        const invalid = FhirFilePayload(
          name: 'bad_file.json',
          content: '{ "resourceType": "Bundle", broken }',
        );

        await expectLater(
          controller.importFhirFiles([valid, invalid]),
          throwsA(isA<FormatException>()),
        );

        // Verify zero records were saved into the database (no partial import)
        expect(controller.records, isEmpty);

        // Verify failed outcome recorded in history
        expect(controller.importHistory, isNotEmpty);
        final failedOutcome = controller.importHistory.first;
        expect(failedOutcome.status, SourceImportOutcomeStatus.failed);
        expect(failedOutcome.sourceKind, SourceImportSourceKind.fhirJson);
      },
    );
  });
}
