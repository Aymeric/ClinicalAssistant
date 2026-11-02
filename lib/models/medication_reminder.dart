import 'package:flutter/material.dart';

import 'health_record.dart';
import 'manual_medication_details.dart';

/// Predefined standard recurrence schedules for medication reminders.
enum MedicationReminderSchedule {
  daily('Once daily', 1, [TimeOfDay(hour: 9, minute: 0)]),
  bid('Twice daily (BID)', 2, [
    TimeOfDay(hour: 9, minute: 0),
    TimeOfDay(hour: 21, minute: 0),
  ]),
  tid('Three times daily (TID)', 3, [
    TimeOfDay(hour: 8, minute: 0),
    TimeOfDay(hour: 14, minute: 0),
    TimeOfDay(hour: 20, minute: 0),
  ]),
  qid('Four times daily (QID)', 4, [
    TimeOfDay(hour: 8, minute: 0),
    TimeOfDay(hour: 12, minute: 0),
    TimeOfDay(hour: 16, minute: 0),
    TimeOfDay(hour: 20, minute: 0),
  ]),
  prn('As needed (PRN)', 0, []);

  const MedicationReminderSchedule(
    this.label,
    this.dosesPerDay,
    this.defaultTimes,
  );

  final String label;
  final int dosesPerDay;
  final List<TimeOfDay> defaultTimes;

  static MedicationReminderSchedule fromString(String? raw) {
    if (raw == null) return MedicationReminderSchedule.daily;
    final clean = raw.toLowerCase().trim();
    if (clean.contains('bid') || clean.contains('twice')) {
      return MedicationReminderSchedule.bid;
    }
    if (clean.contains('tid') ||
        clean.contains('three') ||
        clean.contains('3')) {
      return MedicationReminderSchedule.tid;
    }
    if (clean.contains('qid') ||
        clean.contains('four') ||
        clean.contains('4')) {
      return MedicationReminderSchedule.qid;
    }
    if (clean.contains('prn') || clean.contains('needed')) {
      return MedicationReminderSchedule.prn;
    }
    return MedicationReminderSchedule.daily;
  }
}

/// A configured local medication reminder schedule for an active prescription.
class MedicationReminder {
  const MedicationReminder({
    required this.medicationId,
    required this.medicationName,
    required this.schedule,
    this.times = const [],
    this.isEnabled = true,
  });

  static const sourceDataKey = 'medicationReminder';

  final String medicationId;
  final String medicationName;
  final MedicationReminderSchedule schedule;
  final List<TimeOfDay> times;
  final bool isEnabled;

  List<TimeOfDay> get effectiveTimes =>
      times.isNotEmpty ? times : schedule.defaultTimes;

  Map<String, Object?> toJson() => {
    'medicationId': medicationId,
    'medicationName': medicationName,
    'schedule': schedule.name,
    'isEnabled': isEnabled,
    'times': effectiveTimes
        .map(
          (t) =>
              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
        )
        .toList(),
  };

  factory MedicationReminder.fromJson(Map<String, Object?> json) {
    final timesRaw = json['times'];
    final parsedTimes = <TimeOfDay>[];
    if (timesRaw is List) {
      for (final item in timesRaw) {
        if (item is String) {
          final parts = item.split(':');
          if (parts.length == 2) {
            final h = int.tryParse(parts[0]);
            final m = int.tryParse(parts[1]);
            if (h != null && m != null) {
              parsedTimes.add(TimeOfDay(hour: h, minute: m));
            }
          }
        }
      }
    }

    final schedule = MedicationReminderSchedule.fromString(
      json['schedule']?.toString(),
    );

    return MedicationReminder(
      medicationId: json['medicationId']?.toString() ?? '',
      medicationName: json['medicationName']?.toString() ?? '',
      schedule: schedule,
      isEnabled: json['isEnabled'] as bool? ?? true,
      times: parsedTimes.isNotEmpty ? parsedTimes : schedule.defaultTimes,
    );
  }

  factory MedicationReminder.fromRecord(HealthRecord record) {
    final raw = record.sourceData?[sourceDataKey];
    if (raw is Map) {
      return MedicationReminder.fromJson(Map<String, Object?>.from(raw));
    }
    final details = ManualMedicationDetails.fromRecord(record);
    final schedule = MedicationReminderSchedule.fromString(details.frequency);
    return MedicationReminder(
      medicationId: record.id,
      medicationName: record.name,
      schedule: schedule,
      times: schedule.defaultTimes,
      isEnabled: record.status == 'active' || record.status == null,
    );
  }

  Map<String, Object?> withSourceData(Map<String, Object?>? sourceData) => {
    ...?sourceData,
    sourceDataKey: toJson(),
  };
}
