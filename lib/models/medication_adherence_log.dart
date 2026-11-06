import 'health_record.dart';
import 'manual_medication_details.dart';
import 'medication_reminder.dart';

enum MedicationAdherenceStatus {
  taken('Taken'),
  skipped('Skipped');

  const MedicationAdherenceStatus(this.label);
  final String label;

  static MedicationAdherenceStatus fromString(String? raw) {
    if (raw == 'skipped') return MedicationAdherenceStatus.skipped;
    return MedicationAdherenceStatus.taken;
  }
}

class MedicationAdherenceLog {
  const MedicationAdherenceLog({
    required this.id,
    required this.medicationId,
    required this.medicationName,
    required this.takenAt,
    this.status = MedicationAdherenceStatus.taken,
    this.notes,
  });

  final String id;
  final String medicationId;
  final String medicationName;
  final DateTime takenAt;
  final MedicationAdherenceStatus status;
  final String? notes;

  bool get isTaken => status == MedicationAdherenceStatus.taken;
  bool get isSkipped => status == MedicationAdherenceStatus.skipped;

  Map<String, Object?> toJson() => {
    'id': id,
    'medicationId': medicationId,
    'medicationName': medicationName,
    'takenAt': takenAt.toIso8601String(),
    'status': status.name,
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
  };

  factory MedicationAdherenceLog.fromJson(Map<String, Object?> json) {
    return MedicationAdherenceLog(
      id: json['id'] as String? ?? '',
      medicationId: json['medicationId'] as String? ?? '',
      medicationName: json['medicationName'] as String? ?? '',
      takenAt:
          DateTime.tryParse(json['takenAt'] as String? ?? '') ?? DateTime.now(),
      status: MedicationAdherenceStatus.fromString(json['status'] as String?),
      notes: json['notes'] as String?,
    );
  }
}

enum MedicationDayAdherenceState {
  notPrescribed,
  noLog,
  covered,
  partial,
  skipped,
}

class MedicationAdherenceDaySummary {
  const MedicationAdherenceDaySummary({
    required this.date,
    required this.state,
    required this.takenCount,
    required this.skippedCount,
    required this.expectedDoses,
    required this.logs,
  });

  final DateTime date;
  final MedicationDayAdherenceState state;
  final int takenCount;
  final int skippedCount;
  final int expectedDoses;
  final List<MedicationAdherenceLog> logs;
}

/// Clinical Proportion of Days Covered (PDC) evaluation over a specified day window.
///
/// The standard clinical adherence benchmark is PDC >= 80%.
class MedicationPdcEvaluation {
  const MedicationPdcEvaluation({
    required this.windowDays,
    required this.eligibleDays,
    required this.coveredDays,
    required this.partialDays,
    required this.skippedDays,
    required this.takenDoses,
    required this.skippedDoses,
    required this.expectedDosesPerDay,
    required this.isPrn,
  });

  static const double clinicalBenchmarkPercent = 80.0;

  final int windowDays;
  final int eligibleDays;
  final int coveredDays;
  final int partialDays;
  final int skippedDays;
  final int takenDoses;
  final int skippedDoses;
  final int expectedDosesPerDay;
  final bool isPrn;

  /// Proportion of eligible days covered as a ratio between 0.0 and 1.0.
  double get pdcRatio =>
      eligibleDays <= 0 ? 0.0 : (coveredDays / eligibleDays).clamp(0.0, 1.0);

  /// Proportion of eligible days covered as a percentage (0 to 100).
  double get pdcPercent => pdcRatio * 100.0;

  /// Rounded integer percentage (0 to 100).
  int get pdcPercentRounded => pdcPercent.round();

  /// Whether the PDC score meets or exceeds the standard >= 80% clinical benchmark.
  bool get meetsClinicalBenchmark =>
      !isPrn && eligibleDays > 0 && pdcPercent >= clinicalBenchmarkPercent;

  /// Neutral, descriptive label for the adherence rate.
  String get descriptiveLabel {
    if (isPrn) return 'As needed (PRN)';
    if (eligibleDays == 0) return 'No eligible days in window';
    if (meetsClinicalBenchmark) {
      return '$pdcPercentRounded% PDC ($coveredDays/$eligibleDays days · ≥80% benchmark)';
    }
    return '$pdcPercentRounded% PDC ($coveredDays/$eligibleDays days · <80% benchmark)';
  }

  /// Resolves the expected daily dose count from a medication record's reminder or frequency.
  static int expectedDailyDosesFor(HealthRecord record) {
    final details = ManualMedicationDetails.fromRecord(record);
    final schedule =
        details.reminder?.schedule ??
        MedicationReminderSchedule.fromString(
          details.frequency.trim().isNotEmpty
              ? details.frequency
              : record.value,
        );
    return schedule.dosesPerDay;
  }

  /// Evaluates Proportion of Days Covered (PDC) over [windowDays] ending on [referenceDate].
  static MedicationPdcEvaluation evaluate(
    HealthRecord record, {
    int windowDays = 30,
    DateTime? referenceDate,
  }) {
    final details = ManualMedicationDetails.fromRecord(record);
    final schedule =
        details.reminder?.schedule ??
        MedicationReminderSchedule.fromString(
          details.frequency.trim().isNotEmpty
              ? details.frequency
              : record.value,
        );
    final isPrn = schedule == MedicationReminderSchedule.prn;
    final expectedDosesPerDay = isPrn ? 0 : schedule.dosesPerDay;

    final refLocal = (referenceDate ?? DateTime.now()).toLocal();
    final endDay = DateTime(refLocal.year, refLocal.month, refLocal.day);
    final windowStartDay = endDay.subtract(Duration(days: windowDays - 1));

    final recLocal = record.recordedAt.toLocal();
    final prescriptionStartDay = DateTime(
      recLocal.year,
      recLocal.month,
      recLocal.day,
    );

    DateTime? prescriptionEndDay;
    if (details.endDate != null) {
      final endLocal = details.endDate!.toLocal();
      prescriptionEndDay = DateTime(
        endLocal.year,
        endLocal.month,
        endLocal.day,
      );
    }

    // Group logs by local calendar day
    final logsByDay = <DateTime, List<MedicationAdherenceLog>>{};
    DateTime? earliestLogDay;
    for (final log in details.adherenceLogs) {
      final local = log.takenAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      logsByDay.putIfAbsent(day, () => []).add(log);
      if (earliestLogDay == null || day.isBefore(earliestLogDay)) {
        earliestLogDay = day;
      }
    }

    final effectiveStartDay =
        earliestLogDay != null && earliestLogDay.isBefore(prescriptionStartDay)
        ? earliestLogDay
        : prescriptionStartDay;

    final startDay = effectiveStartDay.isAfter(windowStartDay)
        ? effectiveStartDay
        : windowStartDay;
    final lastEligibleDay =
        prescriptionEndDay != null && prescriptionEndDay.isBefore(endDay)
        ? prescriptionEndDay
        : endDay;

    if (lastEligibleDay.isBefore(startDay)) {
      return MedicationPdcEvaluation(
        windowDays: windowDays,
        eligibleDays: 0,
        coveredDays: 0,
        partialDays: 0,
        skippedDays: 0,
        takenDoses: 0,
        skippedDoses: 0,
        expectedDosesPerDay: expectedDosesPerDay,
        isPrn: isPrn,
      );
    }

    var eligibleDays = 0;
    var coveredDays = 0;
    var partialDays = 0;
    var skippedDays = 0;
    var takenDoses = 0;
    var skippedDoses = 0;

    for (
      var day = startDay;
      !day.isAfter(lastEligibleDay);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      eligibleDays++;
      final dayLogs = logsByDay[day] ?? const [];
      final dayTaken = dayLogs.where((l) => l.isTaken).length;
      final daySkipped = dayLogs.where((l) => l.isSkipped).length;
      takenDoses += dayTaken;
      skippedDoses += daySkipped;

      if (isPrn) {
        if (dayTaken > 0) coveredDays++;
      } else {
        if (dayTaken >= expectedDosesPerDay && expectedDosesPerDay > 0) {
          coveredDays++;
        } else if (dayTaken > 0) {
          // At least one dose taken on a multi-dose day counts as partial,
          // and standard PDC counts a day as covered when daily regimen is met
          // (or when at least 1 dose is logged if 1 dose/day).
          partialDays++;
        } else if (daySkipped > 0) {
          skippedDays++;
        }
      }
    }

    return MedicationPdcEvaluation(
      windowDays: windowDays,
      eligibleDays: eligibleDays,
      coveredDays: coveredDays,
      partialDays: partialDays,
      skippedDays: skippedDays,
      takenDoses: takenDoses,
      skippedDoses: skippedDoses,
      expectedDosesPerDay: expectedDosesPerDay,
      isPrn: isPrn,
    );
  }

  /// Builds daily adherence summaries for a given calendar month ([year], [month]).
  static List<MedicationAdherenceDaySummary> buildMonthCalendar(
    HealthRecord record, {
    required int year,
    required int month,
  }) {
    final details = ManualMedicationDetails.fromRecord(record);
    final schedule =
        details.reminder?.schedule ??
        MedicationReminderSchedule.fromString(
          details.frequency.trim().isNotEmpty
              ? details.frequency
              : record.value,
        );
    final isPrn = schedule == MedicationReminderSchedule.prn;
    final expectedDoses = isPrn ? 1 : schedule.dosesPerDay;

    final recLocal = record.recordedAt.toLocal();
    final prescriptionStartDay = DateTime(
      recLocal.year,
      recLocal.month,
      recLocal.day,
    );
    DateTime? prescriptionEndDay;
    if (details.endDate != null) {
      final endLocal = details.endDate!.toLocal();
      prescriptionEndDay = DateTime(
        endLocal.year,
        endLocal.month,
        endLocal.day,
      );
    }

    final logsByDay = <DateTime, List<MedicationAdherenceLog>>{};
    for (final log in details.adherenceLogs) {
      final local = log.takenAt.toLocal();
      if (local.year == year && local.month == month) {
        final day = DateTime(year, month, local.day);
        logsByDay.putIfAbsent(day, () => []).add(log);
      }
    }

    final daysInMonth = DateTime(year, month + 1, 0).day;
    final summaries = <MedicationAdherenceDaySummary>[];

    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(year, month, d);
      final dayLogs = logsByDay[date] ?? const [];
      final takenCount = dayLogs.where((l) => l.isTaken).length;
      final skippedCount = dayLogs.where((l) => l.isSkipped).length;

      MedicationDayAdherenceState state;
      if (takenCount >= expectedDoses && expectedDoses > 0) {
        state = MedicationDayAdherenceState.covered;
      } else if (takenCount > 0) {
        state = MedicationDayAdherenceState.partial;
      } else if (skippedCount > 0) {
        state = MedicationDayAdherenceState.skipped;
      } else if (date.isBefore(prescriptionStartDay) ||
          (prescriptionEndDay != null && date.isAfter(prescriptionEndDay))) {
        state = MedicationDayAdherenceState.notPrescribed;
      } else {
        state = MedicationDayAdherenceState.noLog;
      }

      summaries.add(
        MedicationAdherenceDaySummary(
          date: date,
          state: state,
          takenCount: takenCount,
          skippedCount: skippedCount,
          expectedDoses: expectedDoses,
          logs: dayLogs,
        ),
      );
    }

    return summaries;
  }
}
