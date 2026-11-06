import 'dart:io';

import 'package:clinical_assistant/controllers/health_data_controller.dart';
import 'package:clinical_assistant/data/encrypted_record_store.dart';
import 'package:clinical_assistant/data/synthetic_demonstration_data.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/models/manual_medication_details.dart';
import 'package:clinical_assistant/models/medication_adherence_log.dart';
import 'package:clinical_assistant/sync/foreground_sync_state.dart';
import 'package:clinical_assistant/sync/import_progress.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRecordStore implements EncryptedRecordStore {
  _FakeRecordStore(this.records);
  final List<HealthRecord> records;

  @override
  Directory? get directory => null;

  @override
  Future<List<HealthRecord>> load() async => List.of(records);

  @override
  Future<void> save(
    List<HealthRecord> records, {
    ImportProgressCallback? onProgress,
  }) async {
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

  test('synthetic demonstration data includes active medications', () {
    final records = generateSyntheticDemonstrationRecords(
      referenceDate: DateTime.utc(2026, 10, 23),
    );
    final medications = records
        .where((record) => record.category == RecordCategory.medication)
        .toList();

    expect(medications, hasLength(2));
    expect(medications.map((record) => record.name), [
      'Atorvastatin',
      'Metformin',
    ]);
    expect(medications.every((record) => record.status == 'active'), isTrue);
    expect(medications.every((record) => isSyntheticRecord(record)), isTrue);
    expect(
      ManualMedicationDetails.fromRecord(medications.first).frequency,
      'Once daily at bedtime',
    );
  });

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

    test(
      'serializes and extracts ManualMedicationDetails with adherenceLogs',
      () {
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
      },
    );
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
      final med = controller.records.firstWhere(
        (r) => r.id == 'med-atorvastatin',
      );
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

    test(
      'discontinues medication with effective end date and reason annotation',
      () async {
        final med = controller.records.firstWhere(
          (r) => r.id == 'med-atorvastatin',
        );
        final stopDate = DateTime.utc(2026, 10, 15);
        await controller.updateMedicationStatus(
          med,
          'discontinued',
          endDate: stopDate,
          discontinueReason: 'Adverse reaction: muscle aches',
        );

        expect(controller.activeMedications.length, 1);
        expect(controller.pastMedications.length, 1);

        final discontinued = controller.records.firstWhere(
          (r) => r.id == 'med-atorvastatin',
        );
        expect(discontinued.status, 'discontinued');

        final details = ManualMedicationDetails.fromRecord(discontinued);
        expect(details.endDate, DateTime(2026, 10, 15));
        expect(details.discontinueReason, 'Adverse reaction: muscle aches');

        // Reactivating clears the discontinue reason and end date
        await controller.updateMedicationStatus(discontinued, 'active');
        final reactivated = controller.records.firstWhere(
          (r) => r.id == 'med-atorvastatin',
        );
        expect(reactivated.status, 'active');
        final reactivatedDetails = ManualMedicationDetails.fromRecord(
          reactivated,
        );
        expect(reactivatedDetails.endDate, isNull);
        expect(reactivatedDetails.discontinueReason, isNull);
      },
    );

    test('updates medication status between active and past', () async {
      final med = controller.records.firstWhere(
        (r) => r.id == 'med-atorvastatin',
      );
      await controller.updateMedicationStatus(med, 'stopped');

      expect(controller.activeMedications.length, 1);
      expect(controller.pastMedications.length, 1);
      expect(controller.pastMedications.first.id, 'med-atorvastatin');

      // Reactivate
      final stoppedMed = controller.records.firstWhere(
        (r) => r.id == 'med-atorvastatin',
      );
      await controller.updateMedicationStatus(stoppedMed, 'active');

      expect(controller.activeMedications.length, 2);
      expect(controller.pastMedications.length, 0);
    });

    test(
      'logs skipped doses and preserves existing reminder schedule',
      () async {
        final testTime = DateTime.utc(2026, 10, 1, 9, 0);
        final med = controller.records.firstWhere(
          (r) => r.id == 'med-atorvastatin',
        );
        await controller.logMedicationDose(
          med,
          takenAt: testTime,
          status: MedicationAdherenceStatus.skipped,
          note: 'Fasting for morning blood draw',
        );

        final updated = controller.records.firstWhere(
          (r) => r.id == 'med-atorvastatin',
        );
        final details = ManualMedicationDetails.fromRecord(updated);
        expect(details.adherenceLogs, hasLength(1));
        expect(details.adherenceLogs.first.isSkipped, isTrue);
        expect(details.adherenceLogs.first.isTaken, isFalse);
        expect(
          details.adherenceLogs.first.status,
          MedicationAdherenceStatus.skipped,
        );
        expect(
          details.adherenceLogs.first.notes,
          'Fasting for morning blood draw',
        );
      },
    );
  });

  group('MedicationPdcEvaluation & Monthly Adherence Calendar', () {
    test(
      'computes 30-, 60-, and 90-day PDC and evaluates >= 80% clinical benchmark',
      () {
        final referenceDate = DateTime(2026, 10, 30, 12, 0);
        // Prescribed 30 days ago (Oct 1 to Oct 30 = 30 eligible days), once daily
        final logs = <MedicationAdherenceLog>[];
        // Log taken on 25 of the 30 days (25 / 30 = 83.3% -> 83% >= 80% benchmark)
        for (var i = 0; i < 25; i++) {
          logs.add(
            MedicationAdherenceLog(
              id: 'log-taken-$i',
              medicationId: 'med-lisinopril',
              medicationName: 'Lisinopril',
              takenAt: DateTime(2026, 10, 1 + i, 9, 0),
              status: MedicationAdherenceStatus.taken,
            ),
          );
        }
        // Log skipped on 2 days (Oct 26 and Oct 27)
        logs.add(
          MedicationAdherenceLog(
            id: 'log-skip-1',
            medicationId: 'med-lisinopril',
            medicationName: 'Lisinopril',
            takenAt: DateTime(2026, 10, 26, 9, 0),
            status: MedicationAdherenceStatus.skipped,
          ),
        );
        logs.add(
          MedicationAdherenceLog(
            id: 'log-skip-2',
            medicationId: 'med-lisinopril',
            medicationName: 'Lisinopril',
            takenAt: DateTime(2026, 10, 27, 9, 0),
            status: MedicationAdherenceStatus.skipped,
          ),
        );

        final record = HealthRecord(
          id: 'med-lisinopril',
          name: 'Lisinopril',
          value: '10 mg',
          unit: '',
          recordedAt: DateTime(2026, 10, 1),
          category: RecordCategory.medication,
          source: 'Manual Entry',
          status: 'active',
          sourceData: ManualMedicationDetails(
            frequency: 'Once daily',
            route: 'Oral',
            adherenceLogs: logs,
          ).withSourceData(null),
        );

        final pdc30 = MedicationPdcEvaluation.evaluate(
          record,
          windowDays: 30,
          referenceDate: referenceDate,
        );

        expect(pdc30.windowDays, 30);
        expect(pdc30.eligibleDays, 30);
        expect(pdc30.coveredDays, 25);
        expect(pdc30.skippedDays, 2);
        expect(pdc30.takenDoses, 25);
        expect(pdc30.skippedDoses, 2);
        expect(pdc30.pdcPercentRounded, 83);
        expect(pdc30.meetsClinicalBenchmark, isTrue);
        expect(pdc30.descriptiveLabel, contains('83% PDC'));
        expect(pdc30.descriptiveLabel, contains('≥80% benchmark'));

        // Over 60-day window, since prescription started Oct 1, eligibleDays is still 30
        final pdc60 = MedicationPdcEvaluation.evaluate(
          record,
          windowDays: 60,
          referenceDate: referenceDate,
        );
        expect(pdc60.eligibleDays, 30);
        expect(pdc60.coveredDays, 25);
        expect(pdc60.pdcPercentRounded, 83);

        // If prescription started 90 days ago, eligibleDays is 90 and 25/90 = 28% (< 80% benchmark)
        final olderRecord = record.copyWith(recordedAt: DateTime(2026, 8, 1));
        final pdc90 = MedicationPdcEvaluation.evaluate(
          olderRecord,
          windowDays: 90,
          referenceDate: referenceDate,
        );
        expect(pdc90.eligibleDays, 90);
        expect(pdc90.coveredDays, 25);
        expect(pdc90.pdcPercentRounded, 28);
        expect(pdc90.meetsClinicalBenchmark, isFalse);
        expect(pdc90.descriptiveLabel, contains('<80% benchmark'));
      },
    );

    test(
      'handles BID (twice daily) partial vs covered days and builds monthly calendar',
      () {
        final logs = <MedicationAdherenceLog>[
          // Oct 10: 2 taken -> covered
          MedicationAdherenceLog(
            id: 'l1',
            medicationId: 'med-metformin',
            medicationName: 'Metformin',
            takenAt: DateTime(2026, 10, 10, 8, 0),
          ),
          MedicationAdherenceLog(
            id: 'l2',
            medicationId: 'med-metformin',
            medicationName: 'Metformin',
            takenAt: DateTime(2026, 10, 10, 20, 0),
          ),
          // Oct 11: 1 taken, 1 skipped -> partial
          MedicationAdherenceLog(
            id: 'l3',
            medicationId: 'med-metformin',
            medicationName: 'Metformin',
            takenAt: DateTime(2026, 10, 11, 8, 0),
          ),
          MedicationAdherenceLog(
            id: 'l4',
            medicationId: 'med-metformin',
            medicationName: 'Metformin',
            takenAt: DateTime(2026, 10, 11, 20, 0),
            status: MedicationAdherenceStatus.skipped,
          ),
          // Oct 12: 1 skipped -> skipped
          MedicationAdherenceLog(
            id: 'l5',
            medicationId: 'med-metformin',
            medicationName: 'Metformin',
            takenAt: DateTime(2026, 10, 12, 8, 0),
            status: MedicationAdherenceStatus.skipped,
          ),
        ];

        final record = HealthRecord(
          id: 'med-metformin',
          name: 'Metformin',
          value: '500 mg',
          unit: '',
          recordedAt: DateTime(2026, 10, 10),
          category: RecordCategory.medication,
          source: 'Manual Entry',
          status: 'active',
          sourceData: ManualMedicationDetails(
            frequency: 'Twice daily (BID)',
            route: 'Oral',
            adherenceLogs: logs,
          ).withSourceData(null),
        );

        final calendar = MedicationPdcEvaluation.buildMonthCalendar(
          record,
          year: 2026,
          month: 10,
        );

        expect(calendar, hasLength(31));
        // Oct 9 (before prescription start) -> notPrescribed
        expect(calendar[8].state, MedicationDayAdherenceState.notPrescribed);
        // Oct 10 -> covered
        expect(calendar[9].state, MedicationDayAdherenceState.covered);
        expect(calendar[9].takenCount, 2);
        // Oct 11 -> partial
        expect(calendar[10].state, MedicationDayAdherenceState.partial);
        expect(calendar[10].takenCount, 1);
        expect(calendar[10].skippedCount, 1);
        // Oct 12 -> skipped
        expect(calendar[11].state, MedicationDayAdherenceState.skipped);
        expect(calendar[11].skippedCount, 1);
        // Oct 13 -> noLog
        expect(calendar[12].state, MedicationDayAdherenceState.noLog);
      },
    );
  });
}
