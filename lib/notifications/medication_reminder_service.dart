import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/health_record.dart';
import '../models/medication_adherence_log.dart';
import '../models/medication_reminder.dart';
import '../sync/foreground_sync_state.dart';
import 'local_notification_dispatcher.dart';

typedef MedicationReminderActionHandler =
    Future<void> Function(
      String medicationId,
      MedicationAdherenceStatus status,
    );

/// Manages recurring local medication reminder notifications.
class MedicationReminderService {
  MedicationReminderService({
    required LocalNotificationDispatcher dispatcher,
    required SyncValueStore syncValueStore,
    this.onDoseAction,
    this.onNotificationTap,
  }) : _dispatcher = dispatcher,
       _store = syncValueStore;

  final LocalNotificationDispatcher _dispatcher;
  final SyncValueStore _store;
  final MedicationReminderActionHandler? onDoseAction;
  final VoidCallback? onNotificationTap;

  static const _remindersStoreKey = 'medication_reminders_v1';
  static const actionMarkTaken =
      FlutterLocalNotificationDispatcher.actionMarkTaken;
  static const actionMarkSkipped =
      FlutterLocalNotificationDispatcher.actionMarkSkipped;

  static const reminderActions = [
    LocalNotificationAction(id: actionMarkTaken, label: 'Taken'),
    LocalNotificationAction(id: actionMarkSkipped, label: 'Skipped'),
  ];

  /// Generates a stable deterministic integer notification ID for a medication and time slot.
  static int notificationIdFor(String medicationId, int hour, int minute) {
    var hash = medicationId.hashCode ^ (hour << 8) ^ minute;
    // Keep positive 31-bit integer for notification plugins
    return hash & 0x7FFFFFFF;
  }

  /// Builds a structured notification payload encoding the medication ID.
  static String payloadForMedication(String medicationId) =>
      'medication:$medicationId';

  /// Extracts the medication ID from a reminder notification payload.
  static String? parseMedicationIdFromPayload(String? payload) {
    if (payload == null || !payload.startsWith('medication:')) return null;
    final id = payload.substring('medication:'.length).trim();
    return id.isEmpty ? null : id;
  }

  /// Initializes the underlying notification dispatcher to listen for Taken / Skipped actions.
  Future<void> initialize() async {
    await _dispatcher.initialize(
      onNotificationTap: onNotificationTap,
      onNotificationAction: handleNotificationResponse,
    );
  }

  /// Processes a notification tap or quick-action response ('mark_taken' / 'mark_skipped').
  Future<void> handleNotificationResponse(
    String? actionId,
    String? payload,
  ) async {
    final medicationId = parseMedicationIdFromPayload(payload);
    if (medicationId == null) {
      onNotificationTap?.call();
      return;
    }
    if (actionId == actionMarkTaken) {
      await onDoseAction?.call(medicationId, MedicationAdherenceStatus.taken);
    } else if (actionId == actionMarkSkipped) {
      await onDoseAction?.call(medicationId, MedicationAdherenceStatus.skipped);
    } else {
      onNotificationTap?.call();
    }
  }

  /// Loads all user-configured medication reminders.
  Future<List<MedicationReminder>> loadReminders() async {
    final raw = await _store.read(_remindersStoreKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map(
              (m) => MedicationReminder.fromJson(Map<String, Object?>.from(m)),
            )
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  /// Saves medication reminders to local persistent storage.
  Future<void> saveReminders(List<MedicationReminder> reminders) async {
    final encoded = jsonEncode(reminders.map((r) => r.toJson()).toList());
    await _store.write(_remindersStoreKey, encoded);
  }

  /// Sets or updates the reminder configuration for a medication.
  Future<void> setReminder(MedicationReminder reminder) async {
    final current = await loadReminders();
    final updated = [
      ...current.where((r) => r.medicationId != reminder.medicationId),
      reminder,
    ];
    await saveReminders(updated);
    if (reminder.isEnabled) {
      await scheduleReminder(reminder);
    } else {
      await cancelReminder(reminder.medicationId);
    }
  }

  /// Cancels all scheduled local reminders for a given medication.
  Future<void> cancelReminder(String medicationId) async {
    final reminders = await loadReminders();
    final existing = reminders.where((r) => r.medicationId == medicationId);
    for (final rem in existing) {
      for (final t in rem.effectiveTimes) {
        final id = notificationIdFor(medicationId, t.hour, t.minute);
        await _dispatcher.cancel(id: id);
      }
    }
  }

  /// Schedules recurring local notification alerts for the given reminder.
  Future<void> scheduleReminder(MedicationReminder reminder) async {
    if (!reminder.isEnabled ||
        reminder.schedule == MedicationReminderSchedule.prn) {
      return;
    }

    await initialize();
    final hasPermission = await _dispatcher.requestPermission();
    if (!hasPermission) return;

    for (final time in reminder.effectiveTimes) {
      final id = notificationIdFor(
        reminder.medicationId,
        time.hour,
        time.minute,
      );
      final hourStr = time.hour.toString().padLeft(2, '0');
      final minStr = time.minute.toString().padLeft(2, '0');
      final timeFormatted = '$hourStr:$minStr';

      await _dispatcher.show(
        id: id,
        title: 'Medication Reminder',
        body:
            'Time to take ${reminder.medicationName} ($timeFormatted · ${reminder.schedule.label})',
        payload: payloadForMedication(reminder.medicationId),
        actions: reminderActions,
      );
    }
  }

  /// Deletes and cancels reminder for a medication.
  Future<void> removeReminder(String medicationId) async {
    await cancelReminder(medicationId);
    final current = await loadReminders();
    final updated = current
        .where((r) => r.medicationId != medicationId)
        .toList();
    await saveReminders(updated);
  }

  /// Synchronizes active medication records with scheduled reminders.
  Future<void> syncWithActiveMedications(List<HealthRecord> medications) async {
    final activeIds = medications
        .where(
          (m) =>
              m.category == RecordCategory.medication && m.status == 'active',
        )
        .map((m) => m.id)
        .toSet();

    final reminders = await loadReminders();
    for (final rem in reminders) {
      if (!activeIds.contains(rem.medicationId)) {
        await cancelReminder(rem.medicationId);
      }
    }
  }
}
