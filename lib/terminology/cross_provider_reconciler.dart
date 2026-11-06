import '../models/health_record.dart';
import 'loinc_dictionary.dart';

/// Represents a cross-provider reconciled clinical observation or test event,
/// grouping identical or equivalent measurements taken on the same date across
/// multiple healthcare providers or portals.
class ReconciledRecordGroup {
  const ReconciledRecordGroup({
    required this.id,
    required this.standardizedName,
    required this.recordedDate,
    required this.canonicalRecord,
    required this.contributingRecords,
    this.loincCode,
  });

  /// Unique identifier for this reconciliation group.
  final String id;

  /// Standardized test or analyte name (from LOINC dictionary or canonical record).
  final String standardizedName;

  /// Normalized calendar date (UTC midnight) of the clinical measurement event.
  final DateTime recordedDate;

  /// The primary or most detailed record representing this measurement.
  final HealthRecord canonicalRecord;

  /// All records (from 2 or more distinct sources/documents) contributing to this group.
  final List<HealthRecord> contributingRecords;

  /// Common LOINC code if known.
  final String? loincCode;

  /// Number of distinct sources contributing to this measurement.
  int get distinctSourceCount =>
      contributingRecords.map((r) => r.source.trim()).toSet().length;

  /// All unique provider/portal source names contributing.
  List<String> get sourceNames =>
      contributingRecords.map((r) => r.source.trim()).toSet().toList();

  /// Whether this group represents a multi-provider duplicate/reconciled entry.
  bool get isMultiProvider => distinctSourceCount > 1;
}

/// Helper service that identifies duplicate and equivalent clinical measurements
/// imported across multiple healthcare providers, hospital portals, and lab services.
///
/// Preserves complete data provenance and never modifies or deletes underlying vault records.
class CrossProviderReconciler {
  const CrossProviderReconciler._();

  // Hoisted pattern for non-alphanumeric character removal during analyte key normalization.
  static final _nonAlphanumeric = RegExp(r'[^a-z0-9]');

  /// Normalizes a date to YYYY-MM-DD string representation in local time.
  static String normalizeDate(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Derives an analyte equivalency key.
  ///
  /// If the record possesses a recognized LOINC code (or alternate code),
  /// the canonical LOINC code is used.
  /// Otherwise, normalizes category and name.
  static String deriveAnalyteKey(HealthRecord record) {
    if (record.code != null && record.code!.trim().isNotEmpty) {
      final concept = LoincDictionary.lookup(record.code);
      if (concept != null) {
        return 'loinc:${concept.code}';
      }
      final normCode = LoincDictionary.normalizeCode(record.code!);
      if (normCode.isNotEmpty) {
        return 'code:$normCode';
      }
    }

    // Check well-known canonical vital terms
    final lower = record.name.toLowerCase();
    if (record.category == RecordCategory.vital) {
      if (lower.contains('systolic')) return 'vital:bp_systolic';
      if (lower.contains('diastolic')) return 'vital:bp_diastolic';
      if (lower.contains('heart rate') || lower.contains('pulse')) {
        return 'vital:heart_rate';
      }
      if (lower.contains('oxygen') || lower.contains('spo2')) {
        return 'vital:oxygen_saturation';
      }
      if (lower.contains('weight') || lower.contains('body mass')) {
        return 'vital:weight';
      }
    }

    final cleanName = record.name
        .toLowerCase()
        .replaceAll(_nonAlphanumeric, '')
        .trim();
    return 'name:${record.category.name}:$cleanName';
  }

  /// Reconciles a list of health records across providers.
  ///
  /// Groups records that:
  /// 1. Belong to the same clinical category (e.g. lab or vital).
  /// 2. Measure the same equivalent analyte/test (by LOINC code or normalized title).
  /// 3. Occurred on the exact same calendar date.
  /// 4. Originate from at least two different providers/sources or separate reports.
  ///
  /// Returns a map of `record.id` to its corresponding [ReconciledRecordGroup].
  static Map<String, ReconciledRecordGroup> findReconciledGroups(
    Iterable<HealthRecord> records,
  ) {
    final groupsByKey = <String, List<HealthRecord>>{};

    for (final record in records) {
      // Focus on lab tests and vitals for cross-provider reconciliation
      if (record.category != RecordCategory.lab &&
          record.category != RecordCategory.vital) {
        continue;
      }

      final dateStr = normalizeDate(record.recordedAt);
      final analyteKey = deriveAnalyteKey(record);
      final groupKey = '$dateStr|$analyteKey';

      groupsByKey.putIfAbsent(groupKey, () => []).add(record);
    }

    final resultMap = <String, ReconciledRecordGroup>{};

    for (final entry in groupsByKey.entries) {
      final candidates = entry.value;
      if (candidates.length < 2) continue;

      // Check if there are distinct sources or distinct record IDs with identical/near-identical values
      final sources = candidates.map((r) => r.source.trim()).toSet();
      if (sources.length < 2) {
        // Even from the same named source, if source IDs differ and measurements match on the same day,
        // it may represent duplicate ingestion from different documents/portals
        final sourceIds = candidates.map((r) => r.sourceId ?? r.id).toSet();
        if (sourceIds.length < 2) continue;
      }

      // Choose canonical record (prefer record with LOINC code, or reference range, or manual/verified status)
      final canonical = _pickCanonicalRecord(candidates);
      final standardizedName = LoincDictionary.resolvePatientFriendlyName(
        canonical,
      );
      final loincConcept = LoincDictionary.lookup(canonical.code);

      final group = ReconciledRecordGroup(
        id: entry.key,
        standardizedName: standardizedName,
        recordedDate: DateTime(
          canonical.recordedAt.year,
          canonical.recordedAt.month,
          canonical.recordedAt.day,
        ),
        canonicalRecord: canonical,
        contributingRecords: List.unmodifiable(candidates),
        loincCode: loincConcept?.code ?? canonical.code,
      );

      for (final member in candidates) {
        resultMap[member.id] = group;
      }
    }

    return resultMap;
  }

  static HealthRecord _pickCanonicalRecord(List<HealthRecord> candidates) {
    var best = candidates.first;
    var bestScore = _scoreRecordCompleteness(best);

    for (var i = 1; i < candidates.length; i++) {
      final score = _scoreRecordCompleteness(candidates[i]);
      if (score > bestScore) {
        best = candidates[i];
        bestScore = score;
      }
    }
    return best;
  }

  static int _scoreRecordCompleteness(HealthRecord record) {
    var score = 0;
    if (record.code != null && record.code!.isNotEmpty) score += 3;
    if (record.referenceRange != null && record.referenceRange!.isNotEmpty) {
      score += 2;
    }
    if (record.sourceData != null && record.sourceData!.isNotEmpty) score += 1;
    if (record.status != null) score += 1;
    return score;
  }
}
