import 'dart:io';

import 'package:clinical_assistant/controllers/health_data_controller.dart';
import 'package:clinical_assistant/data/encrypted_record_store.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/models/manual_medication_details.dart';
import 'package:clinical_assistant/models/medication_reminder.dart';
import 'package:clinical_assistant/notifications/local_notification_dispatcher.dart';
import 'package:clinical_assistant/notifications/medication_reminder_service.dart';
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
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _RecordingNotificationDispatcher implements LocalNotificationDispatcher {
  bool requestPermissionResult = true;
  final List<Map<String, Object?>> shownNotifications = [];
  final List<int> cancelledNotificationIds = [];

  @override
  Future<void> initialize({VoidCallback? onNotificationTap}) async {}

  @override
  Future<bool> requestPermission() async => requestPermissionResult;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    shownNotifications.add({'id': id, 'title': title, 'body': body});
  }

  @override
  Future<void> cancel({required int id}) async {
    cancelledNotificationIds.add(id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MedicationReminderSchedule', () {
    test('fromString resolves standard frequencies and variations', () {
      expect(
        MedicationReminderSchedule.fromString('daily'),
        MedicationReminderSchedule.daily,
      );
      expect(
        MedicationReminderSchedule.fromString('Once daily in morning'),
        MedicationReminderSchedule.daily,
      );
      expect(
        MedicationReminderSchedule.fromString('BID - twice daily'),
        MedicationReminderSchedule.bid,
      );
      expect(
        MedicationReminderSchedule.fromString('Take 3 times daily (tid)'),
        MedicationReminderSchedule.tid,
      );
      expect(
        MedicationReminderSchedule.fromString('QID 4 times a day'),
        MedicationReminderSchedule.qid,
      );
      expect(
        MedicationReminderSchedule.fromString('Take as needed for pain (PRN)'),
        MedicationReminderSchedule.prn,
      );
      expect(
        MedicationReminderSchedule.fromString(null),
        MedicationReminderSchedule.daily,
      );
    });

    test('default times are configured for each schedule', () {
      expect(MedicationReminderSchedule.daily.defaultTimes.length, 1);
      expect(MedicationReminderSchedule.bid.defaultTimes.length, 2);
      expect(MedicationReminderSchedule.tid.defaultTimes.length, 3);
      expect(MedicationReminderSchedule.qid.defaultTimes.length, 4);
      expect(MedicationReminderSchedule.prn.defaultTimes.length, 0);
    });
  });

  group('MedicationReminder serialization and models', () {
    test('JSON serialization round-trip retains times and state', () {
      const reminder = MedicationReminder(
        medicationId: 'med-123',
        medicationName: 'Metformin',
        schedule: MedicationReminderSchedule.bid,
        times: [
          TimeOfDay(hour: 8, minute: 30),
          TimeOfDay(hour: 20, minute: 15),
        ],
        isEnabled: true,
      );

      final json = reminder.toJson();
      final restored = MedicationReminder.fromJson(json);

      expect(restored.medicationId, 'med-123');
      expect(restored.medicationName, 'Metformin');
      expect(restored.schedule, MedicationReminderSchedule.bid);
      expect(restored.isEnabled, isTrue);
      expect(restored.effectiveTimes.length, 2);
      expect(restored.effectiveTimes[0].hour, 8);
      expect(restored.effectiveTimes[0].minute, 30);
      expect(restored.effectiveTimes[1].hour, 20);
      expect(restored.effectiveTimes[1].minute, 15);
    });

    test('fromRecord constructs reminder from HealthRecord sourceData', () {
      const reminder = MedicationReminder(
        medicationId: 'rec-1',
        medicationName: 'Lisinopril',
        schedule: MedicationReminderSchedule.daily,
        times: [TimeOfDay(hour: 9, minute: 0)],
        isEnabled: true,
      );
      final details = ManualMedicationDetails(
        frequency: 'daily',
        reminder: reminder,
      );
      final record = HealthRecord(
        id: 'rec-1',
        name: 'Lisinopril',
        value: '10mg',
        unit: '',
        category: RecordCategory.medication,
        status: 'active',
        source: 'Manual Entry',
        recordedAt: DateTime(2026, 1, 1),
        sourceData: details.withSourceData(null),
      );

      final extracted = MedicationReminder.fromRecord(record);
      expect(extracted.medicationId, 'rec-1');
      expect(extracted.medicationName, 'Lisinopril');
      expect(extracted.schedule, MedicationReminderSchedule.daily);
      expect(extracted.isEnabled, isTrue);
    });
  });

  group('MedicationReminderService', () {
    late _RecordingNotificationDispatcher dispatcher;
    late _MemorySyncValueStore syncStore;
    late MedicationReminderService service;

    setUp(() {
      dispatcher = _RecordingNotificationDispatcher();
      syncStore = _MemorySyncValueStore();
      service = MedicationReminderService(
        dispatcher: dispatcher,
        syncValueStore: syncStore,
      );
    });

    test(
      'scheduleReminder schedules notifications for each effective time',
      () async {
        const reminder = MedicationReminder(
          medicationId: 'med-1',
          medicationName: 'Atorvastatin',
          schedule: MedicationReminderSchedule.daily,
          times: [TimeOfDay(hour: 21, minute: 0)],
          isEnabled: true,
        );

        await service.scheduleReminder(reminder);

        expect(dispatcher.shownNotifications.length, 1);
        final alert = dispatcher.shownNotifications.first;
        expect(alert['title'], 'Medication Reminder');
        expect((alert['body'] as String).contains('Atorvastatin'), isTrue);
        expect((alert['body'] as String).contains('21:00'), isTrue);
      },
    );

    test('scheduleReminder skips scheduling when disabled or PRN', () async {
      const disabledReminder = MedicationReminder(
        medicationId: 'med-2',
        medicationName: 'Ibuprofen',
        schedule: MedicationReminderSchedule.daily,
        isEnabled: false,
      );
      await service.scheduleReminder(disabledReminder);
      expect(dispatcher.shownNotifications, isEmpty);

      const prnReminder = MedicationReminder(
        medicationId: 'med-3',
        medicationName: 'Albuterol',
        schedule: MedicationReminderSchedule.prn,
        isEnabled: true,
      );
      await service.scheduleReminder(prnReminder);
      expect(dispatcher.shownNotifications, isEmpty);
    });

    test('cancelReminder cancels all time slots for medication', () async {
      const reminder = MedicationReminder(
        medicationId: 'med-10',
        medicationName: 'Amoxicillin',
        schedule: MedicationReminderSchedule.bid,
        times: [TimeOfDay(hour: 8, minute: 0), TimeOfDay(hour: 20, minute: 0)],
        isEnabled: true,
      );
      await service.saveReminders([reminder]);
      await service.cancelReminder('med-10');

      expect(dispatcher.cancelledNotificationIds.length, 2);
      final id1 = MedicationReminderService.notificationIdFor('med-10', 8, 0);
      final id2 = MedicationReminderService.notificationIdFor('med-10', 20, 0);
      expect(dispatcher.cancelledNotificationIds, contains(id1));
      expect(dispatcher.cancelledNotificationIds, contains(id2));
    });

    test(
      'syncWithActiveMedications cancels reminders for non-active medications',
      () async {
        const reminder1 = MedicationReminder(
          medicationId: 'active-1',
          medicationName: 'Metformin',
          schedule: MedicationReminderSchedule.daily,
        );
        const reminder2 = MedicationReminder(
          medicationId: 'past-2',
          medicationName: 'Cephalexin',
          schedule: MedicationReminderSchedule.daily,
        );
        await service.saveReminders([reminder1, reminder2]);

        final records = <HealthRecord>[
          HealthRecord(
            id: 'active-1',
            name: 'Metformin',
            value: '500mg',
            unit: '',
            category: RecordCategory.medication,
            status: 'active',
            source: 'Manual Entry',
            recordedAt: DateTime.now(),
          ),
          HealthRecord(
            id: 'past-2',
            name: 'Cephalexin',
            value: '250mg',
            unit: '',
            category: RecordCategory.medication,
            status: 'discontinued',
            source: 'Manual Entry',
            recordedAt: DateTime.now(),
          ),
        ];

        await service.syncWithActiveMedications(records);

        final expectedCancelledId = MedicationReminderService.notificationIdFor(
          'past-2',
          9,
          0,
        );
        expect(
          dispatcher.cancelledNotificationIds,
          contains(expectedCancelledId),
        );
      },
    );
  });

  group('MedicationsPage Reminder UX', () {
    testWidgets(
      'renders reminder chips and opens reminder configuration dialog',
      (tester) async {
        final records = <HealthRecord>[
          HealthRecord(
            id: 'med-test-1',
            name: 'Levothyroxine',
            value: '50mcg',
            unit: '',
            category: RecordCategory.medication,
            status: 'active',
            source: 'Manual Entry',
            recordedAt: DateTime(2026, 1, 1),
            sourceData: const ManualMedicationDetails(
              frequency: 'Once daily',
              reminder: MedicationReminder(
                medicationId: 'med-test-1',
                medicationName: 'Levothyroxine',
                schedule: MedicationReminderSchedule.daily,
                isEnabled: true,
              ),
            ).withSourceData(null),
          ),
        ];

        final store = _FakeRecordStore(records);
        final syncStore = _MemorySyncValueStore();
        final dispatcher = _RecordingNotificationDispatcher();
        final reminderService = MedicationReminderService(
          dispatcher: dispatcher,
          syncValueStore: syncStore,
        );
        final controller = HealthDataController(
          store: store,
          syncValueStore: syncStore,
        );
        await controller.load();

        await tester.pumpWidget(
          MaterialApp(
            home: MedicationsPage(
              controller: controller,
              reminderService: reminderService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify the reminder chip is displayed
        expect(find.text('Once daily'), findsWidgets);
        expect(find.byIcon(Icons.alarm_on), findsOneWidget);

        // Tap on the reminder chip to open dialog
        await tester.tap(find.byIcon(Icons.alarm_on));
        await tester.pumpAndSettle();

        expect(find.text('Reminder: Levothyroxine'), findsOneWidget);
        expect(find.text('Enable reminders'), findsOneWidget);
        expect(find.text('Frequency schedule'), findsOneWidget);
        expect(find.text('Reminder times'), findsOneWidget);
        expect(find.text('Save'), findsOneWidget);

        // Tap Save
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(find.text('Reminder: Levothyroxine'), findsNothing);
        expect(
          find.textContaining('Reminder scheduled for Levothyroxine'),
          findsOneWidget,
        );
      },
    );
  });
}
