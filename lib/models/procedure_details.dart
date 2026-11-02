import 'health_record.dart';

/// Represents structured clinical procedure or surgery details parsed from
/// an HL7 FHIR Procedure resource or Apple Health Clinical Records procedureRecord.
class ProcedureDetails {
  const ProcedureDetails({
    required this.name,
    this.status,
    this.performedDate,
    this.bodySite,
    this.outcome,
    this.performer,
    this.reason,
    this.code,
  });

  /// Name of the procedure or surgical intervention (e.g., 'Appendectomy', 'Knee Arthroscopy').
  final String name;

  /// Clinical status of the procedure (e.g., 'completed', 'in-progress', 'preparation').
  final String? status;

  /// Date and time when the procedure was performed or started.
  final DateTime? performedDate;

  /// Anatomical location or body site (e.g., 'Right knee', 'Appendix').
  final String? bodySite;

  /// Outcome of the procedure if recorded (e.g., 'Successful', 'Uncomplicated').
  final String? outcome;

  /// Practitioner or healthcare facility that performed the procedure.
  final String? performer;

  /// Stated reason or indication for the procedure.
  final String? reason;

  /// Coded terminology (e.g., SNOMED CT or CPT code).
  final String? code;

  /// Extracts structured [ProcedureDetails] from a [HealthRecord]'s `sourceData`.
  static ProcedureDetails? fromRecord(HealthRecord record) {
    if (record.category != RecordCategory.procedure) return null;
    final source = record.sourceData;
    if (source == null) {
      return ProcedureDetails(
        name: record.name,
        status: record.status,
        performedDate: record.recordedAt,
        code: record.code,
      );
    }

    final rawSite = source['bodySite'];
    String? bodySite;
    if (rawSite is List && rawSite.isNotEmpty) {
      final first = rawSite.first;
      if (first is Map) {
        bodySite = first['text']?.toString().trim();
        if (bodySite == null || bodySite.isEmpty) {
          final codings = first['coding'];
          if (codings is List && codings.isNotEmpty && codings.first is Map) {
            bodySite = codings.first['display']?.toString().trim();
          }
        }
      }
    } else if (rawSite is Map) {
      bodySite = rawSite['text']?.toString().trim();
      if (bodySite == null || bodySite.isEmpty) {
        final codings = rawSite['coding'];
        if (codings is List && codings.isNotEmpty && codings.first is Map) {
          bodySite = codings.first['display']?.toString().trim();
        }
      }
    }

    final rawOutcome = source['outcome'];
    String? outcome;
    if (rawOutcome is Map) {
      outcome = rawOutcome['text']?.toString().trim();
      if (outcome == null || outcome.isEmpty) {
        final codings = rawOutcome['coding'];
        if (codings is List && codings.isNotEmpty && codings.first is Map) {
          outcome = codings.first['display']?.toString().trim();
        }
      }
    }

    final rawPerformer = source['performer'];
    String? performer;
    if (rawPerformer is List && rawPerformer.isNotEmpty) {
      final actors = <String>[];
      for (final p in rawPerformer) {
        if (p is Map) {
          final actor = p['actor'];
          if (actor is Map) {
            final display = actor['display']?.toString().trim();
            if (display != null && display.isNotEmpty) {
              actors.add(display);
            }
          }
        }
      }
      if (actors.isNotEmpty) {
        performer = actors.join(', ');
      }
    }

    final rawReason = source['reasonCode'];
    String? reason;
    if (rawReason is List && rawReason.isNotEmpty) {
      final reasons = <String>[];
      for (final r in rawReason) {
        if (r is Map) {
          final text = r['text']?.toString().trim();
          if (text != null && text.isNotEmpty) {
            reasons.add(text);
          } else {
            final codings = r['coding'];
            if (codings is List && codings.isNotEmpty && codings.first is Map) {
              final d = codings.first['display']?.toString().trim();
              if (d != null && d.isNotEmpty) reasons.add(d);
            }
          }
        }
      }
      if (reasons.isNotEmpty) reason = reasons.join(', ');
    }

    return ProcedureDetails(
      name: record.name,
      status: record.status ?? source['status']?.toString(),
      performedDate: record.recordedAt,
      bodySite: bodySite,
      outcome: outcome,
      performer: performer,
      reason: reason,
      code: record.code,
    );
  }
}
