import 'dart:io';

import 'package:clinical_assistant/controllers/health_data_controller.dart';
import 'package:clinical_assistant/data/encrypted_record_store.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/models/manual_medication_details.dart';
import 'package:clinical_assistant/models/medication_adherence_log.dart';
import 'package:clinical_assistant/sync/foreground_sync_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRecordStore implements EncryptedRecordStore {
  _FakeRecordStore(this.records);
  final List<HealthRecord> records;

  @override
  Directory? get directory => null;

  @override
  Future<List<HealthRecord>> load() async => List.of(records);

  @override
  Future<void> save(List<HealthRecord> records) async {
    this.records
      ..clear()
      ..addAll(records);
  }

  @override
  Future<bool> verifyIntegrity() async => true;

  @override
  Future<void> clear() async => records.clear();
}

class _MemorySyncValueStore implements SyncValueStore {
  final _values = <String, String>{};
  @override
  Future<String?> read(String key) async => _values[key];
  @override
  Future<void> write(String key, String value) async => _values[key] = value;
  @override
  Future<void> delete(String key) async => _values.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Medication Adherence Model', () {
    test('serializes and deserializes MedicationAdherenceLog', () {
      final log = MedicationAdherenceLog(
        id: 'log-1',
        medicationId: 'med-atorvastatin',
        medicationName: 'Atorvastatin',
        takenAt: DateTime.utc(2026, 9, 30, 8, 30),
        notes: 'Taken with breakfast',
      );

      final json = log.toJson();
      expect(json['id'], 'log-1');
      expect(json['medicationId'], 'med-atorvastatin');
      expect(json['medicationName'], 'Atorvastatin');
      expect(json['notes'], 'Taken with breakfast');

      final deserialized = MedicationAdherenceLog.fromJson(json);
      expect(deserialized.id, log.id);
      expect(deserialized.medicationId, log.medicationId);
      expect(deserialized.medicationName, log.medicationName);
      expect(deserialized.takenAt, log.takenAt);
      expect(deserialized.notes, log.notes);
    });

    test('serializes and extracts ManualMedicationDetails with adherenceLogs', () {
      final log = MedicationAdherenceLog(
        id: 'log-10',
        medicationId: 'med-10',
        medicationName: 'Lisinopril',
        takenAt: DateTime.utc(2026, 9, 30, 12, 0),
        notes: 'Noon dose',
      );
      final details = ManualMedicationDetails(
        frequency: 'Daily',
        route: 'Oral',
        adherenceLogs: [log],
      );

      final sourceData = details.withSourceData(null);
      final record = HealthRecord(
        id: 'med-10',
        name: 'Lisinopril',
        value: '10mg',
        unit: '',
        recordedAt: DateTime.utc(2026, 9, 1),
        category: RecordCategory.medication,
        source: 'Manual Entry',
        sourceData: sourceData,
      );

      final parsed = ManualMedicationDetails.fromRecord(record);
      expect(parsed.frequency, 'Daily');
      expect(parsed.route, 'Oral');
      expect(parsed.adherenceLogs.length, 1);
      expect(parsed.adherenceLogs.first.id, 'log-10');
      expect(parsed.adherenceLogs.first.notes, 'Noon dose');
    });
  });

  group('HealthDataController Medication Management', () {
    late _FakeRecordStore store;
    late HealthDataController controller;
    late HealthRecord initialMed;
    late HealthRecord portalMed;

    setUp(() async {
      initialMed = HealthRecord(
        id: 'med-atorvastatin',
        name: 'Atorvastatin',
        value: '20 mg oral tablet once daily',
        unit: '',
        recordedAt: DateTime.utc(2026, 9, 1),
        category: RecordCategory.medication,
        source: 'Manual Entry',
        referenceRange: 'active',
        sourceData: const ManualMedicationDetails(
          frequency: 'Once daily at bedtime',
          route: 'Oral',
        ).withSourceData(null),
      );

      portalMed = HealthRecord(
        id: 'med-amoxicillin',
        name: 'Amoxicillin',
        value: '500 mg',
        unit: '',
        recordedAt: DateTime.utc(2026, 8, 1),
        category: RecordCategory.medication,
        source: 'Hospital Portal',
      );

      store = _FakeRecordStore([initialMed, portalMed]);
      controller = HealthDataController(
        store: store,
        syncValueStore: _MemorySyncValueStore(),
      );
      await controller.load();
    });

    test('categorizes active and past medications', () {
      expect(controller.activeMedications.length, 2);
      expect(controller.pastMedications.length, 0);

      final names = controller.activeMedications.map((m) => m.name).toList();
      expect(names, contains('Atorvastatin'));
      expect(names, contains('Amoxicillin'));
    });

    test('logs dose adherence for a medication', () async {
      final testTime = DateTime.utc(2026, 9, 30, 21, 0);
      final med = controller.records.firstWhere((r) => r.id == 'med-atorvastatin');
      await controller.logMedicationDose(
        med,
        takenAt: testTime,
        note: 'Taken with water before bed',
      );

      final updated = controller.records.firstWhere(
        (r) => r.id == 'med-atorvastatin',
      );
      final details = ManualMedicationDetails.fromRecord(updated);

      expect(details.adherenceLogs.length, 1);
      expect(details.adherenceLogs.first.notes, 'Taken with water before bed');
      expect(details.adherenceLogs.first.takenAt, testTime);
      expect(details.adherenceLogs.first.medicationName, 'Atorvastatin');
    });

    test('updates medication status between active and past', () async {
      final med = controller.records.firstWhere((r) => r.id == 'med-atorvastatin');
      await controller.updateMedicationStatus(med, 'stopped');

      expect(controller.activeMedications.length, 1);
      expect(controller.pastMedications.length, 1);
      expect(controller.pastMedications.first.id, 'med-atorvastatin');

      // Reactivate
      final stoppedMed = controller.records.firstWhere((r) => r.id == 'med-atorvastatin');
      await controller.updateMedicationStatus(stoppedMed, 'active');

      expect(controller.activeMedications.length, 2);
      expect(controller.pastMedications.length, 0);
    });
  });
}
