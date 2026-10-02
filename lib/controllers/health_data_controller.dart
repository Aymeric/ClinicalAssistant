import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/encrypted_record_store.dart';
import '../data/pinned_metrics_preferences.dart';
import '../data/synthetic_demonstration_data.dart';
import '../data/vault_backup_service.dart';
import '../integrations/fhir_observation_parser.dart';
import '../integrations/fhir_portal_importer.dart';
import '../integrations/health_platform_importer.dart';
import '../models/health_record.dart';
import '../models/manual_medication_details.dart';
import '../models/medication_adherence_log.dart';
import '../records/manual_record_edit_sheet.dart';
import '../sync/foreground_sync_state.dart';
import '../sync/import_progress.dart';

class HealthDataController extends ChangeNotifier {
  HealthDataController({
    EncryptedRecordStore? store,
    HealthPlatformImporter? healthImporter,
    FhirPortalImporter? fhirImporter,
    FlutterSecureStorage? secureStorage,
    SyncValueStore? syncValueStore,
    PinnedMetricsPreferences? pinnedPreferences,
    VaultBackupService? vaultBackupService,
  }) : _store = store ?? EncryptedRecordStore(),
       _healthImporter = healthImporter ?? HealthPlatformImporter(),
       _fhirImporter = fhirImporter ?? FhirPortalImporter(),
       _syncValueStore =
           syncValueStore ??
           SecureSyncValueStore(
             storage: secureStorage ?? const FlutterSecureStorage(),
           ),
       _pinnedPreferences =
           pinnedPreferences ??
           PinnedMetricsPreferences(
             storage:
                 syncValueStore ??
                 SecureSyncValueStore(
                   storage: secureStorage ?? const FlutterSecureStorage(),
                 ),
           ),
       _vaultBackupService = vaultBackupService ?? VaultBackupService();

  static const _fhirBaseKey = 'fhir_base_url_v1';
  static const _fhirClientKey = 'fhir_client_id_v1';
  static const _healthAutoSyncKey = 'health_auto_sync_v1';
  static const _fhirAutoSyncKey = 'fhir_auto_sync_v1';
  static const _lastHealthSyncKey = 'last_health_sync_v1';
  static const _lastFhirSyncKey = 'last_fhir_sync_v1';
  static const _fhirRefreshTokenKey = 'fhir_refresh_token_v1';
  static const _fhirPatientIdKey = 'fhir_patient_id_v1';
  static const _fhirAuthorizationEndpointKey = 'fhir_authorization_endpoint_v1';
  static const _fhirTokenEndpointKey = 'fhir_token_endpoint_v1';
  final EncryptedRecordStore _store;
  final HealthPlatformImporter _healthImporter;
  final FhirPortalImporter _fhirImporter;
  final SyncValueStore _syncValueStore;
  final PinnedMetricsPreferences _pinnedPreferences;
  final VaultBackupService _vaultBackupService;
  List<HealthRecord> records = const [];
  bool loading = true;
  bool busy = false;
  Object? error;
  SyncValueStore get syncValueStore => _syncValueStore;
  PinnedMetricsPreferences get pinnedPreferences => _pinnedPreferences;
  VaultBackupService get vaultBackupService => _vaultBackupService;

  @override
  void dispose() {
    _fhirImporter.close();
    super.dispose();
  }

  int get healthRecordCount => records
      .where(
        (record) =>
            record.id.startsWith('health:') ||
            record.id.startsWith('health-clinical:'),
      )
      .length;
  int get fhirRecordCount =>
      records.where((record) => record.id.startsWith('fhir:')).length;
  int get syntheticRecordCount => records.where(isSyntheticRecord).length;

  List<HealthRecord> get activeMedications => records
      .where(
        (r) =>
            r.category == RecordCategory.medication &&
            (r.status == 'active' ||
                (r.status == null &&
                    (r.referenceRange == null ||
                        r.referenceRange!.isEmpty ||
                        r.referenceRange == 'active'))),
      )
      .toList();

  List<HealthRecord> get pastMedications => records
      .where(
        (r) =>
            r.category == RecordCategory.medication &&
            (r.status == 'stopped' ||
                r.status == 'completed' ||
                (r.status != null &&
                    r.status != 'active' &&
                    r.status != 'on-hold') ||
                (r.status == null &&
                    r.referenceRange != null &&
                    r.referenceRange!.isNotEmpty &&
                    r.referenceRange != 'active')),
      )
      .toList();

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      records = await _store.load();
    } catch (exception) {
      error = exception;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<List<HealthRecord>> importHealth({
    required DateTime since,
    ImportProgressCallback? onProgress,
  }) async {
    return _withBusy(() async {
      final imported = await _healthImporter.importRecords(
        since: since,
        onProgress: (progress) => onProgress?.call(progress.scale(0.9)),
      );
      if (imported.isEmpty) {
        throw StateError(
          'No supported health records or clinical lab results were returned. Check the date range and review the requested permissions.',
        );
      }
      onProgress?.call(
        const ImportProgress(
          fraction: 0.95,
          message: 'Saving imported records',
        ),
      );
      final newlyImported = await _mergeAndSave(imported);
      await _recordSuccessfulSync(_lastHealthSyncKey);
      onProgress?.call(
        const ImportProgress(fraction: 1, message: 'Import complete'),
      );
      return newlyImported;
    });
  }

  Future<void> setHealthAutoSync(bool enabled) =>
      _syncValueStore.write(_healthAutoSyncKey, enabled.toString());

  Future<void> disableFhirAutoSync() async {
    await _syncValueStore.write(_fhirAutoSyncKey, 'false');
    await Future.wait([
      _syncValueStore.delete(_fhirRefreshTokenKey),
      _syncValueStore.delete(_fhirPatientIdKey),
      _syncValueStore.delete(_fhirAuthorizationEndpointKey),
      _syncValueStore.delete(_fhirTokenEndpointKey),
    ]);
  }

  Future<ForegroundSyncState> loadForegroundSyncState() async {
    final values = await Future.wait([
      _syncValueStore.read(_healthAutoSyncKey),
      _syncValueStore.read(_fhirAutoSyncKey),
      _syncValueStore.read(_fhirRefreshTokenKey),
      _syncValueStore.read(_fhirPatientIdKey),
      _syncValueStore.read(_fhirAuthorizationEndpointKey),
      _syncValueStore.read(_fhirTokenEndpointKey),
      _syncValueStore.read(_lastHealthSyncKey),
      _syncValueStore.read(_lastFhirSyncKey),
    ]);
    return ForegroundSyncState(
      healthAutoSync: _readStoredBoolean(values[0], _healthAutoSyncKey),
      fhirAutoSync: _readStoredBoolean(values[1], _fhirAutoSyncKey),
      fhirRefreshTokenAvailable:
          values[2] != null &&
          values[3] != null &&
          values[4] != null &&
          values[5] != null,
      lastHealthSyncAt: _readStoredDate(values[6], _lastHealthSyncKey),
      lastFhirSyncAt: _readStoredDate(values[7], _lastFhirSyncKey),
    );
  }

  Future<List<HealthRecord>> importFhir({
    required String baseUrl,
    required String clientId,
    ImportProgressCallback? onProgress,
  }) async {
    final result = await connectFhir(
      baseUrl: baseUrl,
      clientId: clientId,
      onProgress: onProgress,
    );
    if (result.fetchedRecordCount == 0) {
      throw StateError(
        'The provider returned no supported laboratory Observations.',
      );
    }
    return result.newlyImported;
  }

  Future<FhirConnectionOutcome> connectFhir({
    required String baseUrl,
    required String clientId,
    bool rememberPortalForAutoSync = false,
    ImportProgressCallback? onProgress,
  }) async {
    return _withBusy(() async {
      final result = await _fhirImporter.authorizeAndImportLabResults(
        fhirBaseUrl: baseUrl,
        clientId: clientId,
        requestRefreshToken: rememberPortalForAutoSync,
        resourceTypes: FhirPortalImporter.clinicalResourceTypes,
        onProgress: (progress) => onProgress?.call(progress.scale(0.9)),
      );
      await Future.wait([
        _syncValueStore.write(_fhirBaseKey, baseUrl.trim()),
        _syncValueStore.write(_fhirClientKey, clientId.trim()),
      ]);
      final canAutoSync =
          rememberPortalForAutoSync && result.refreshToken != null;
      if (canAutoSync) {
        await Future.wait([
          _syncValueStore.write(_fhirRefreshTokenKey, result.refreshToken!),
          _syncValueStore.write(_fhirPatientIdKey, result.patientId),
          _syncValueStore.write(
            _fhirAuthorizationEndpointKey,
            result.authorizationEndpoint,
          ),
          _syncValueStore.write(_fhirTokenEndpointKey, result.tokenEndpoint),
          _syncValueStore.write(_fhirAutoSyncKey, 'true'),
        ]);
      } else {
        await disableFhirAutoSync();
      }
      onProgress?.call(
        const ImportProgress(
          fraction: 0.95,
          message: 'Saving imported records',
        ),
      );
      final newlyImported = result.records.isEmpty
          ? const <HealthRecord>[]
          : await _mergeAndSave(result.records);
      await _recordSuccessfulSync(_lastFhirSyncKey);
      onProgress?.call(
        const ImportProgress(fraction: 1, message: 'Import complete'),
      );
      return FhirConnectionOutcome(
        newlyImported: newlyImported,
        fetchedRecordCount: result.records.length,
        autoSyncEnabled: canAutoSync,
        autoSyncUnavailable:
            rememberPortalForAutoSync && result.refreshToken == null,
      );
    });
  }

  Future<List<HealthRecord>> syncHealth({
    ImportProgressCallback? onProgress,
  }) async {
    return _withBusy(() async {
      final lastSync = _readStoredDate(
        await _syncValueStore.read(_lastHealthSyncKey),
        _lastHealthSyncKey,
      );
      final since =
          lastSync?.subtract(const Duration(days: 3)) ?? DateTime(1900);
      final imported = await _healthImporter.importRecords(
        since: since,
        onProgress: (progress) => onProgress?.call(progress.scale(0.9)),
      );
      final newlyImported = imported.isEmpty
          ? const <HealthRecord>[]
          : await _mergeAndSave(imported);
      await _recordSuccessfulSync(_lastHealthSyncKey);
      onProgress?.call(
        const ImportProgress(fraction: 1, message: 'Health sync complete'),
      );
      return newlyImported;
    });
  }

  Future<List<HealthRecord>> syncFhir({
    ImportProgressCallback? onProgress,
  }) async {
    return _withBusy(() async {
      final values = await Future.wait([
        _syncValueStore.read(_fhirBaseKey),
        _syncValueStore.read(_fhirClientKey),
        _syncValueStore.read(_fhirRefreshTokenKey),
        _syncValueStore.read(_fhirPatientIdKey),
        _syncValueStore.read(_fhirAuthorizationEndpointKey),
        _syncValueStore.read(_fhirTokenEndpointKey),
        _syncValueStore.read(_lastFhirSyncKey),
      ]);
      final baseUrl = values[0];
      final clientId = values[1];
      final refreshToken = values[2];
      final patientId = values[3];
      final authorizationEndpoint = values[4];
      final tokenEndpoint = values[5];
      if (baseUrl == null ||
          clientId == null ||
          refreshToken == null ||
          patientId == null ||
          authorizationEndpoint == null ||
          tokenEndpoint == null) {
        throw StateError(
          'The saved FHIR portal authorization is incomplete. Reauthorize the portal to resume automatic sync.',
        );
      }
      final lastSync = _readStoredDate(values[6], _lastFhirSyncKey);
      final since = lastSync?.subtract(const Duration(days: 3));
      final result = await _fhirImporter.refreshAndImportLabResults(
        fhirBaseUrl: baseUrl,
        clientId: clientId,
        patientId: patientId,
        refreshToken: refreshToken,
        authorizationEndpoint: authorizationEndpoint,
        tokenEndpoint: tokenEndpoint,
        since: since,
        resourceTypes: FhirPortalImporter.clinicalResourceTypes,
        onRefreshTokenUpdated: (token) =>
            _syncValueStore.write(_fhirRefreshTokenKey, token),
        onProgress: (progress) => onProgress?.call(progress.scale(0.9)),
      );
      final newlyImported = result.records.isEmpty
          ? const <HealthRecord>[]
          : await _mergeAndSave(result.records);
      await _recordSuccessfulSync(_lastFhirSyncKey);
      onProgress?.call(
        const ImportProgress(fraction: 1, message: 'Portal sync complete'),
      );
      return newlyImported;
    });
  }

  Future<List<HealthRecord>> _mergeAndSave(List<HealthRecord> imported) async {
    final existingIds = records.map((record) => record.id).toSet();
    final addedIds = <String>{};
    final newlyImported = imported
        .where(
          (record) =>
              !existingIds.contains(record.id) && addedIds.add(record.id),
        )
        .toList();
    final merged = <String, HealthRecord>{
      for (final record in records) record.id: record,
      for (final record in imported) record.id: record,
    }.values.toList()..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    await _store.save(merged);
    records = merged;
    return newlyImported;
  }

  Future<void> addManualRecords(List<HealthRecord> newRecords) async {
    await _mergeAndSave(newRecords);
    notifyListeners();
  }

  Future<void> updateRecordNotes(String recordId, String? notes) async {
    final updated = records.map((record) {
      if (record.id == recordId) {
        return record.copyWith(notes: notes);
      }
      return record;
    }).toList();
    await _store.save(updated);
    records = updated;
    notifyListeners();
  }

  Future<void> updateManualRecords(List<HealthRecord> editedRecords) async {
    final updated = applyManualRecordEdits(records, editedRecords);
    await _store.save(updated);
    records = updated;
    notifyListeners();
  }

  Future<void> deleteRecord(String recordId) async {
    final remaining = records.where((r) => r.id != recordId).toList();
    await _store.save(remaining);
    records = remaining;
    notifyListeners();
  }

  Future<void> logMedicationDose(
    HealthRecord med, {
    DateTime? takenAt,
    String? note,
  }) async {
    final details = ManualMedicationDetails.fromRecord(med);
    final log = MedicationAdherenceLog(
      id: 'adherence:${DateTime.now().millisecondsSinceEpoch}',
      medicationId: med.id,
      medicationName: med.name,
      takenAt: takenAt ?? DateTime.now(),
      notes: note,
    );
    final updatedDetails = ManualMedicationDetails(
      frequency: details.frequency.trim().isEmpty ? 'As directed' : details.frequency,
      route: details.route,
      endDate: details.endDate,
      adherenceLogs: [...details.adherenceLogs, log],
    );
    final updatedRecord = med.copyWith(
      status: med.status ?? 'active',
      sourceData: updatedDetails.withSourceData(med.sourceData),
    );
    await updateManualRecords([updatedRecord]);
  }

  Future<void> updateMedicationStatus(
    HealthRecord med,
    String newStatus, {
    DateTime? endDate,
  }) async {
    final details = ManualMedicationDetails.fromRecord(med);
    final updatedDetails = ManualMedicationDetails(
      frequency: details.frequency.trim().isEmpty ? 'As directed' : details.frequency,
      route: details.route,
      endDate: (newStatus == 'active' || newStatus == 'on-hold')
          ? null
          : (endDate ?? DateTime.now()),
      adherenceLogs: details.adherenceLogs,
    );
    final updatedRecord = med.copyWith(
      status: newStatus,
      referenceRange: newStatus,
      sourceData: updatedDetails.withSourceData(med.sourceData),
    );
    await updateManualRecords([updatedRecord]);
  }

  Future<String> exportVaultBackup(String passphrase) async {
    return _vaultBackupService.exportEncryptedBackup(records, passphrase);
  }

  Future<int> restoreVaultBackup(
    String backupJson,
    String passphrase, {
    bool replaceAll = false,
  }) async {
    return _withBusy(() async {
      final restored = await _vaultBackupService.restoreEncryptedBackup(
        backupJson,
        passphrase,
      );
      if (replaceAll) {
        final sorted = restored
          ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
        await _store.save(sorted);
        records = sorted;
        notifyListeners();
        return sorted.length;
      } else {
        final newlyImported = await _mergeAndSave(restored);
        notifyListeners();
        return newlyImported.length;
      }
    });
  }

  Future<void> clear() async {
    await _syncValueStore.write(_healthAutoSyncKey, 'false');
    await disableFhirAutoSync();
    await Future.wait([
      _syncValueStore.delete(_lastHealthSyncKey),
      _syncValueStore.delete(_lastFhirSyncKey),
    ]);
    await _store.clear();
    records = const [];
    notifyListeners();
  }

  Future<List<HealthRecord>> loadSyntheticDemoRecords({
    ImportProgressCallback? onProgress,
  }) async {
    return _withBusy(() async {
      onProgress?.call(
        const ImportProgress(
          fraction: 0.2,
          message: 'Preparing demonstration records',
        ),
      );
      final demoRecords = generateSyntheticDemonstrationRecords();
      onProgress?.call(
        const ImportProgress(
          fraction: 0.6,
          message: 'Saving demonstration records',
        ),
      );
      final newlyImported = await _mergeAndSave(demoRecords);
      onProgress?.call(
        const ImportProgress(
          fraction: 1,
          message: 'Demonstration records ready',
        ),
      );
      return newlyImported;
    });
  }

  Future<int> clearSyntheticDemoRecords() async {
    return _withBusy(() async {
      final initialCount = records.length;
      final remaining = records.where((r) => !isSyntheticRecord(r)).toList();
      final removedCount = initialCount - remaining.length;
      if (removedCount > 0) {
        records = remaining;
        await _store.save(records);
        notifyListeners();
      }
      return removedCount;
    });
  }

  Future<List<HealthRecord>> importFhirJson(
    String jsonString, {
    String source = 'FHIR File',
    ImportProgressCallback? onProgress,
  }) async {
    return _withBusy(() async {
      onProgress?.call(
        const ImportProgress(fraction: 0.2, message: 'Parsing FHIR data'),
      );
      const parser = FhirObservationParser();
      final imported = parser.parseJson(jsonString, source: source);
      if (imported.isEmpty) {
        throw StateError(
          'No supported laboratory Observations were found in the provided FHIR data.',
        );
      }
      onProgress?.call(
        const ImportProgress(fraction: 0.7, message: 'Saving imported records'),
      );
      final newlyImported = await _mergeAndSave(imported);
      onProgress?.call(
        const ImportProgress(fraction: 1, message: 'FHIR import complete'),
      );
      return newlyImported;
    });
  }

  Future<void> _recordSuccessfulSync(String key) =>
      _syncValueStore.write(key, DateTime.now().toUtc().toIso8601String());

  bool _readStoredBoolean(String? value, String key) {
    if (value == null || value == 'false') return false;
    if (value == 'true') return true;
    throw FormatException('The saved sync setting "$key" is invalid.');
  }

  DateTime? _readStoredDate(String? value, String key) {
    if (value == null) return null;
    final date = DateTime.tryParse(value);
    if (date == null) {
      throw FormatException('The saved sync date "$key" is invalid.');
    }
    return date.toUtc();
  }

  Future<T> _withBusy<T>(Future<T> Function() action) async {
    if (busy) throw StateError('An import is already in progress.');
    busy = true;
    notifyListeners();
    try {
      return await action();
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}

class FhirConnectionOutcome {
  const FhirConnectionOutcome({
    required this.newlyImported,
    required this.fetchedRecordCount,
    required this.autoSyncEnabled,
    required this.autoSyncUnavailable,
  });

  final List<HealthRecord> newlyImported;
  final int fetchedRecordCount;
  final bool autoSyncEnabled;
  final bool autoSyncUnavailable;
}

typedef FhirPortalConnectCallback =
    Future<FhirConnectionOutcome?> Function({
      required String baseUrl,
      required String clientId,
      required bool rememberPortalForAutoSync,
      required ImportProgressCallback onProgress,
    });
