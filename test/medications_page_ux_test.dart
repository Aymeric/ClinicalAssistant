import 'dart:io';

import 'package:clinical_assistant/controllers/health_data_controller.dart';
import 'package:clinical_assistant/data/encrypted_record_store.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/models/manual_medication_details.dart';
import 'package:clinical_assistant/sync/foreground_sync_state.dart';
import 'package:clinical_assistant/sync/import_progress.dart';
import 'package:clinical_assistant/ui/medications/medications_page.dart';
import 'package:flutter/material.dart';
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
  testWidgets(
    'MedicationsPage delete option prompts confirmation dialog before deleting record',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final medRecord = HealthRecord(
        id: 'med-123',
        name: 'Lisinopril',
        category: RecordCategory.medication,
        value: '10mg',
        unit: 'daily',
        recordedAt: DateTime.now(),
        source: 'Manual entry',
        referenceRange: 'active',
        sourceData: const ManualMedicationDetails(
          frequency: 'Daily',
          route: 'Oral',
        ).withSourceData(null),
      );

      final store = _FakeRecordStore([medRecord]);
      final controller = HealthDataController(
        store: store,
        syncValueStore: _MemorySyncValueStore(),
      );
      await controller.load();

      await tester.pumpWidget(
        MaterialApp(home: MedicationsPage(controller: controller)),
      );

      await tester.pumpAndSettle();

      expect(find.text('Lisinopril'), findsOneWidget);

      // Verify 'Mark Taken' button tooltip
      final markTakenTooltipFinder = find.byType(Tooltip);
      expect(markTakenTooltipFinder, findsWidgets);
      final markTakenTooltip = tester.widget<Tooltip>(
        find.ancestor(
          of: find.byKey(const ValueKey('log-dose-Lisinopril')),
          matching: find.byType(Tooltip),
        ),
      );
      expect(markTakenTooltip.message, equals('Log a dose immediately'));

      // Open popup menu on the medication card
      final popupMenuFinder = find.byIcon(Icons.more_vert);
      expect(popupMenuFinder, findsOneWidget);
      await tester.tap(popupMenuFinder);
      await tester.pumpAndSettle();

      // Tap Delete in menu
      final deleteOptionFinder = find.text('Delete');
      expect(deleteOptionFinder, findsOneWidget);
      await tester.tap(deleteOptionFinder);
      await tester.pumpAndSettle();

      // Verify delete confirmation dialog appears
      expect(find.text('Delete Lisinopril?'), findsOneWidget);
      expect(
        find.text(
          'Are you sure you want to delete this medication and its adherence history? This action cannot be undone.',
        ),
        findsOneWidget,
      );

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Medication should still exist
      expect(controller.activeMedications.length, equals(1));
      expect(find.text('Lisinopril'), findsOneWidget);

      // Open popup menu again and confirm delete
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Tap Delete inside confirmation dialog
      final dialogDeleteButton = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete'),
      );
      await tester.tap(dialogDeleteButton);
      await tester.pumpAndSettle();

      // Medication should now be deleted
      expect(controller.activeMedications.isEmpty, equals(true));
      expect(find.text('Deleted Lisinopril'), findsOneWidget);
    },
  );
}
