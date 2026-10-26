import '../models/health_record.dart';
import '../models/manual_medication_details.dart';

/// Distinguishes whether a medication event represents starting or discontinuing therapy.
enum MedicationChartEventType {
  started('Started'),
  ended('Discontinued');

  const MedicationChartEventType(this.label);
  final String label;
}

/// A chronological medication milestone (start or end date) aligned with a trend chart window.
class MedicationChartEvent {
  const MedicationChartEvent({
    required this.medication,
    required this.date,
    required this.type,
  });

  final HealthRecord medication;
  final DateTime date;
  final MedicationChartEventType type;

  String get medicationName => medication.name;
  String get dose => medication.value;
  String get source => medication.source;

  /// Extracts chronological medication start and end events from [records] that fall
  /// strictly within the inclusive range `[start, end]`.
  static List<MedicationChartEvent> extractEvents(
    List<HealthRecord> records, {
    required DateTime start,
    required DateTime end,
  }) {
    final events = <MedicationChartEvent>[];
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;

    for (final record in records) {
      if (record.category != RecordCategory.medication) continue;

      // 1. Medication start event (recordedAt)
      final recordedMs = record.recordedAt.millisecondsSinceEpoch;
      if (recordedMs >= startMs && recordedMs <= endMs) {
        events.add(
          MedicationChartEvent(
            medication: record,
            date: record.recordedAt,
            type: MedicationChartEventType.started,
          ),
        );
      }

      // 2. Medication end date if recorded
      final details = ManualMedicationDetails.fromRecord(record);
      if (details.endDate != null) {
        final endEventMs = details.endDate!.millisecondsSinceEpoch;
        if (endEventMs >= startMs && endEventMs <= endMs) {
          events.add(
            MedicationChartEvent(
              medication: record,
              date: details.endDate!,
              type: MedicationChartEventType.ended,
            ),
          );
        }
      }
    }

    events.sort((a, b) => a.date.compareTo(b.date));
    return events;
  }
}
