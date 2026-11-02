import 'dart:convert';

import '../models/health_record.dart';
import 'foreground_sync_state.dart';

/// Identifies which clinical or device source an import/sync operation targeted.
enum SourceImportSourceKind {
  healthPlatform('health_platform', 'Apple Health / Health Connect'),
  fhirPortal('fhir_portal', 'SMART on FHIR Portals'),
  fhirJson('fhir_json', 'FHIR Bundle JSON');

  const SourceImportSourceKind(this.storageKey, this.defaultLabel);

  final String storageKey;
  final String defaultLabel;

  static SourceImportSourceKind fromStorageKey(String? raw) {
    for (final value in SourceImportSourceKind.values) {
      if (value.storageKey == raw) return value;
    }
    return SourceImportSourceKind.healthPlatform;
  }
}

/// Outcome of a manual import or automatic sync attempt for a data source.
enum SourceImportOutcomeStatus {
  /// The source check succeeded and returned one or more records.
  succeeded('succeeded', 'Updated'),

  /// The source check succeeded without error, but returned 0 records.
  empty('empty', 'No records returned'),

  /// The source check failed due to permissions, auth, network, or format error.
  failed('failed', 'Failed');

  const SourceImportOutcomeStatus(this.storageKey, this.badgeLabel);

  final String storageKey;
  final String badgeLabel;

  static SourceImportOutcomeStatus fromStorageKey(String? raw) {
    for (final value in SourceImportOutcomeStatus.values) {
      if (value.storageKey == raw) return value;
    }
    return SourceImportOutcomeStatus.failed;
  }
}

/// A single recorded import or sync attempt for a source.
class SourceImportEvent {
  const SourceImportEvent({
    required this.sourceKind,
    required this.sourceLabel,
    required this.timestamp,
    required this.isAutoSync,
    required this.status,
    this.fetchedCount = 0,
    this.addedCount = 0,
    int? fetchedRawSampleCount,
    int? addedRawSampleCount,
    this.oldestRecordAt,
    this.newestRecordAt,
    this.errorSummary,
  }) : fetchedRawSampleCount = fetchedRawSampleCount ?? fetchedCount,
       addedRawSampleCount = addedRawSampleCount ?? addedCount;

  final SourceImportSourceKind sourceKind;
  final String sourceLabel;
  final DateTime timestamp;
  final bool isAutoSync;
  final SourceImportOutcomeStatus status;
  final int fetchedCount;
  final int addedCount;
  final int fetchedRawSampleCount;
  final int addedRawSampleCount;
  final DateTime? oldestRecordAt;
  final DateTime? newestRecordAt;
  final String? errorSummary;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sourceKind': sourceKind.storageKey,
    'sourceLabel': sourceLabel,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'isAutoSync': isAutoSync,
    'status': status.storageKey,
    'fetchedCount': fetchedCount,
    'addedCount': addedCount,
    'fetchedRawSampleCount': fetchedRawSampleCount,
    'addedRawSampleCount': addedRawSampleCount,
    if (oldestRecordAt != null)
      'oldestRecordAt': oldestRecordAt!.toUtc().toIso8601String(),
    if (newestRecordAt != null)
      'newestRecordAt': newestRecordAt!.toUtc().toIso8601String(),
    if (errorSummary != null && errorSummary!.isNotEmpty)
      'errorSummary': errorSummary,
  };

  factory SourceImportEvent.fromJson(Map<String, dynamic> json) {
    final timestampRaw = json['timestamp'] as String?;
    final oldestRaw = json['oldestRecordAt'] as String?;
    final newestRaw = json['newestRecordAt'] as String?;
    final fetchedCount = (json['fetchedCount'] as num?)?.toInt() ?? 0;
    final addedCount = (json['addedCount'] as num?)?.toInt() ?? 0;
    return SourceImportEvent(
      sourceKind: SourceImportSourceKind.fromStorageKey(
        json['sourceKind'] as String?,
      ),
      sourceLabel:
          (json['sourceLabel'] as String?) ??
          SourceImportSourceKind.fromStorageKey(
            json['sourceKind'] as String?,
          ).defaultLabel,
      timestamp:
          (timestampRaw != null ? DateTime.tryParse(timestampRaw) : null)
              ?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      isAutoSync: json['isAutoSync'] == true,
      status: SourceImportOutcomeStatus.fromStorageKey(
        json['status'] as String?,
      ),
      fetchedCount: fetchedCount,
      addedCount: addedCount,
      fetchedRawSampleCount:
          (json['fetchedRawSampleCount'] as num?)?.toInt() ?? fetchedCount,
      addedRawSampleCount:
          (json['addedRawSampleCount'] as num?)?.toInt() ?? addedCount,
      oldestRecordAt: oldestRaw != null
          ? DateTime.tryParse(oldestRaw)?.toUtc()
          : null,
      newestRecordAt: newestRaw != null
          ? DateTime.tryParse(newestRaw)?.toUtc()
          : null,
      errorSummary: json['errorSummary'] as String?,
    );
  }

  /// Creates an event from a list of fetched and newly added [HealthRecord]s.
  factory SourceImportEvent.fromRecords({
    required SourceImportSourceKind sourceKind,
    String? sourceLabel,
    required DateTime timestamp,
    required bool isAutoSync,
    required List<HealthRecord> fetchedRecords,
    required List<HealthRecord> newlyAddedRecords,
  }) {
    if (fetchedRecords.isEmpty) {
      return SourceImportEvent(
        sourceKind: sourceKind,
        sourceLabel: sourceLabel ?? sourceKind.defaultLabel,
        timestamp: timestamp.toUtc(),
        isAutoSync: isAutoSync,
        status: SourceImportOutcomeStatus.empty,
      );
    }

    DateTime oldest = fetchedRecords.first.recordedAt.toUtc();
    DateTime newest = fetchedRecords.first.recordedAt.toUtc();
    for (final record in fetchedRecords.skip(1)) {
      final dt = record.recordedAt.toUtc();
      if (dt.isBefore(oldest)) oldest = dt;
      if (dt.isAfter(newest)) newest = dt;
    }

    return SourceImportEvent(
      sourceKind: sourceKind,
      sourceLabel: sourceLabel ?? sourceKind.defaultLabel,
      timestamp: timestamp.toUtc(),
      isAutoSync: isAutoSync,
      status: SourceImportOutcomeStatus.succeeded,
      fetchedCount: fetchedRecords.length,
      addedCount: newlyAddedRecords.length,
      fetchedRawSampleCount: countRawSamples(fetchedRecords),
      addedRawSampleCount: countRawSamples(newlyAddedRecords),
      oldestRecordAt: oldest,
      newestRecordAt: newest,
    );
  }
}

/// Observed coverage and latest activity summary for a specific source group.
class SourceCoverageSummary {
  const SourceCoverageSummary({
    required this.sourceKind,
    required this.sourceLabel,
    required this.recordCount,
    required this.distinctSourceNames,
    int? rawSampleCount,
    this.oldestRecordedAt,
    this.newestRecordedAt,
    this.lastEvent,
  }) : rawSampleCount = rawSampleCount ?? recordCount;

  final SourceImportSourceKind sourceKind;
  final String sourceLabel;
  final int recordCount;
  final int rawSampleCount;
  final List<String> distinctSourceNames;
  final DateTime? oldestRecordedAt;
  final DateTime? newestRecordedAt;
  final SourceImportEvent? lastEvent;

  bool get hasStoredRecords =>
      recordCount > 0 && oldestRecordedAt != null && newestRecordedAt != null;
}

/// Sanitizes an exception or error into a concise, non-PHI user-facing summary.
String sanitizeImportErrorSummary(Object error) {
  var text = error.toString().trim();
  for (final prefix in const [
    'Bad state: ',
    'FormatException: ',
    'Exception: ',
    'Invalid argument(s): ',
  ]) {
    if (text.startsWith(prefix)) {
      text = text.substring(prefix.length).trim();
    }
  }
  // Redact any embedded URLs with query parameters or tokens.
  text = text.replaceAll(RegExp(r'https?://\S+'), '[endpoint]');
  // Security: Redact Bearer tokens and sensitive OAuth credential parameters in error messages.
  text = text.replaceAll(
    RegExp(r'bearer\s+[a-zA-Z0-9._\-~+/=]+', caseSensitive: false),
    'Bearer [redacted]',
  );
  text = text.replaceAllMapped(
    RegExp(
      r'(access_token|refresh_token|client_secret|code)=[^&\s]+',
      caseSensitive: false,
    ),
    (match) => '${match[1]}=[redacted]',
  );
  // Collapse whitespace.
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty) {
    return 'Source check could not be completed.';
  }
  if (text.length > 140) {
    return '${text.substring(0, 137)}...';
  }
  return text;
}

/// Classifies whether [record] originated from Apple Health / Health Connect.
bool isHealthPlatformRecord(HealthRecord record) {
  return record.id.startsWith('health:') ||
      record.id.startsWith('health-clinical:') ||
      record.source == 'Apple Health' ||
      record.source == 'Health Connect' ||
      record.source.startsWith('Apple Health (') ||
      record.source.startsWith('Health Connect (');
}

/// Classifies whether [record] originated from a pasted or imported FHIR JSON bundle.
bool isFhirJsonRecord(HealthRecord record) {
  return record.id.startsWith('fhir-file:') ||
      record.source == 'FHIR File' ||
      record.source == 'FHIR Bundle' ||
      record.source == 'FHIR JSON';
}

/// Classifies whether [record] originated from a SMART on FHIR portal connection.
bool isFhirPortalRecord(HealthRecord record) {
  if (isFhirJsonRecord(record)) return false;
  return record.id.startsWith('fhir:') ||
      record.source.startsWith('SMART on FHIR');
}

/// Builds per-source coverage summaries from the stored vault [records] and [history].
List<SourceCoverageSummary> buildSourceCoverageSummaries(
  List<HealthRecord> records,
  List<SourceImportEvent> history,
) {
  SourceCoverageSummary buildForKind(
    SourceImportSourceKind kind,
    bool Function(HealthRecord) predicate,
  ) {
    final matching = records.where(predicate).toList(growable: false);
    DateTime? oldest;
    DateTime? newest;
    final distinctSources = <String>{};
    for (final record in matching) {
      final dt = record.recordedAt.toUtc();
      if (oldest == null || dt.isBefore(oldest)) oldest = dt;
      if (newest == null || dt.isAfter(newest)) newest = dt;
      if (record.source.trim().isNotEmpty) {
        distinctSources.add(record.source.trim());
      }
    }

    SourceImportEvent? lastEvent;
    for (final event in history) {
      if (event.sourceKind == kind) {
        if (lastEvent == null || event.timestamp.isAfter(lastEvent.timestamp)) {
          lastEvent = event;
        }
      }
    }

    final sortedSources = distinctSources.toList()..sort();
    return SourceCoverageSummary(
      sourceKind: kind,
      sourceLabel: kind.defaultLabel,
      recordCount: matching.length,
      rawSampleCount: countRawSamples(matching),
      distinctSourceNames: sortedSources,
      oldestRecordedAt: oldest,
      newestRecordedAt: newest,
      lastEvent: lastEvent,
    );
  }

  final healthSummary = buildForKind(
    SourceImportSourceKind.healthPlatform,
    isHealthPlatformRecord,
  );
  final fhirPortalSummary = buildForKind(
    SourceImportSourceKind.fhirPortal,
    isFhirPortalRecord,
  );
  final fhirJsonSummary = buildForKind(
    SourceImportSourceKind.fhirJson,
    isFhirJsonRecord,
  );

  return <SourceCoverageSummary>[
    healthSummary,
    fhirPortalSummary,
    if (fhirJsonSummary.recordCount > 0 || fhirJsonSummary.lastEvent != null)
      fhirJsonSummary,
  ];
}

/// Persists bounded [SourceImportEvent] history in [SyncValueStore].
class SourceImportHistoryStore {
  const SourceImportHistoryStore({
    required SyncValueStore storage,
    this.maxEvents = 30,
  }) : _storage = storage;

  static const storageKey = 'source_import_history_v1';

  final SyncValueStore _storage;
  final int maxEvents;

  Future<List<SourceImportEvent>> load() async {
    try {
      final raw = await _storage.read(storageKey);
      if (raw == null || raw.trim().isEmpty) return const <SourceImportEvent>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <SourceImportEvent>[];
      final events = <SourceImportEvent>[];
      for (final item in decoded) {
        if (item is Map) {
          events.add(
            SourceImportEvent.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
      events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return List<SourceImportEvent>.unmodifiable(events);
    } catch (_) {
      return const <SourceImportEvent>[];
    }
  }

  Future<List<SourceImportEvent>> recordEvent(SourceImportEvent event) async {
    final current = await load();
    final updated = <SourceImportEvent>[event, ...current];
    updated.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final bounded = updated.length > maxEvents
        ? updated.sublist(0, maxEvents)
        : updated;
    await _storage.write(
      storageKey,
      jsonEncode(bounded.map((e) => e.toJson()).toList(growable: false)),
    );
    return List<SourceImportEvent>.unmodifiable(bounded);
  }

  Future<void> clear() => _storage.delete(storageKey);
}
