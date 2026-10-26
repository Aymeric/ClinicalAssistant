import 'package:clinical_assistant/controllers/health_data_controller.dart';
import 'package:clinical_assistant/data/encrypted_record_store.dart';
import 'package:clinical_assistant/integrations/fhir_portal_importer.dart';
import 'package:clinical_assistant/integrations/health_platform_importer.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/notifications/result_notification_manager.dart';
import 'package:clinical_assistant/notifications/result_notification_preferences.dart';
import 'package:clinical_assistant/sync/foreground_sync_state.dart';
import 'package:clinical_assistant/sync/import_progress.dart';
import 'package:clinical_assistant/sync/source_import_history.dart';
import 'package:clinical_assistant/ui/connections/connections_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('SourceImportEvent & SourceImportHistoryStore', () {
    test(
      'serializes and deserializes SourceImportEvent and caps stored events',
      () async {
        final store = _MemorySyncValueStore();
        final historyStore = SourceImportHistoryStore(
          storage: store,
          maxEvents: 3,
        );

        final event1 = SourceImportEvent.fromRecords(
          sourceKind: SourceImportSourceKind.healthPlatform,
          timestamp: DateTime.utc(2026, 3, 1, 10),
          isAutoSync: false,
          fetchedRecords: [
            _record(
              'health:1',
              recordedAt: DateTime.utc(2025, 6, 10),
              source: 'Apple Health',
            ),
            _record(
              'health:2',
              recordedAt: DateTime.utc(2026, 2, 20),
              source: 'Apple Health',
            ),
          ],
          newlyAddedRecords: [
            _record(
              'health:2',
              recordedAt: DateTime.utc(2026, 2, 20),
              source: 'Apple Health',
            ),
          ],
        );
        final event2 = SourceImportEvent.fromRecords(
          sourceKind: SourceImportSourceKind.fhirPortal,
          sourceLabel: 'SMART on FHIR (epic.example.org)',
          timestamp: DateTime.utc(2026, 3, 2, 10),
          isAutoSync: true,
          fetchedRecords: const [],
          newlyAddedRecords: const [],
        );
        final event3 = SourceImportEvent(
          sourceKind: SourceImportSourceKind.fhirPortal,
          sourceLabel: 'SMART on FHIR (epic.example.org)',
          timestamp: DateTime.utc(2026, 3, 3, 10),
          isAutoSync: true,
          status: SourceImportOutcomeStatus.failed,
          errorSummary: sanitizeImportErrorSummary(
            StateError(
              'Token refresh failed at https://epic.example.org/oauth2/token?secret=123',
            ),
          ),
        );
        final event4 = SourceImportEvent.fromRecords(
          sourceKind: SourceImportSourceKind.fhirJson,
          sourceLabel: 'Hospital FHIR Export',
          timestamp: DateTime.utc(2026, 3, 4, 10),
          isAutoSync: false,
          fetchedRecords: [
            _record(
              'fhir-file:1',
              recordedAt: DateTime.utc(2026, 3, 4),
              source: 'FHIR File',
            ),
          ],
          newlyAddedRecords: [
            _record(
              'fhir-file:1',
              recordedAt: DateTime.utc(2026, 3, 4),
              source: 'FHIR File',
            ),
          ],
        );

        await historyStore.recordEvent(event1);
        await historyStore.recordEvent(event2);
        await historyStore.recordEvent(event3);
        final loaded = await historyStore.recordEvent(event4);

        expect(loaded, hasLength(3));
        expect(loaded[0].sourceKind, SourceImportSourceKind.fhirJson);
        expect(loaded[0].status, SourceImportOutcomeStatus.succeeded);
        expect(loaded[0].fetchedCount, 1);
        expect(loaded[0].addedCount, 1);

        expect(loaded[1].status, SourceImportOutcomeStatus.failed);
        expect(loaded[1].errorSummary, 'Token refresh failed at [endpoint]');

        expect(loaded[2].status, SourceImportOutcomeStatus.empty);
        expect(loaded[2].isAutoSync, isTrue);

        await historyStore.clear();
        expect(await historyStore.load(), isEmpty);
      },
    );

    test(
      'buildSourceCoverageSummaries computes per-source counts and date spans',
      () {
        final records = <HealthRecord>[
          _record(
            'health:a',
            recordedAt: DateTime.utc(2024, 5, 1),
            source: 'Apple Health',
          ),
          _record(
            'health:b',
            recordedAt: DateTime.utc(2026, 1, 15),
            source: 'Apple Health',
          ),
          _record(
            'fhir:obs-1',
            recordedAt: DateTime.utc(2025, 11, 20),
            source: 'SMART on FHIR (mychart.example.org)',
          ),
        ];

        final summaries = buildSourceCoverageSummaries(records, const []);
        expect(summaries, hasLength(2));

        final healthSummary = summaries.firstWhere(
          (s) => s.sourceKind == SourceImportSourceKind.healthPlatform,
        );
        expect(healthSummary.recordCount, 2);
        expect(healthSummary.oldestRecordedAt, DateTime.utc(2024, 5, 1));
        expect(healthSummary.newestRecordedAt, DateTime.utc(2026, 1, 15));
        expect(healthSummary.distinctSourceNames, ['Apple Health']);

        final fhirSummary = summaries.firstWhere(
          (s) => s.sourceKind == SourceImportSourceKind.fhirPortal,
        );
        expect(fhirSummary.recordCount, 1);
        expect(fhirSummary.oldestRecordedAt, DateTime.utc(2025, 11, 20));
        expect(fhirSummary.newestRecordedAt, DateTime.utc(2025, 11, 20));
        expect(fhirSummary.distinctSourceNames, [
          'SMART on FHIR (mychart.example.org)',
        ]);
      },
    );
  });

  group('HealthDataController import history integration', () {
    test(
      'records succeeded, empty, and failed outcomes across health and FHIR operations and clears on delete',
      () async {
        final healthImporter = _FakeHealthImporter([
          [
            _record(
              'health:1',
              recordedAt: DateTime.utc(2025, 4, 10),
              source: 'Apple Health',
            ),
          ],
          const [],
        ]);
        final fhirImporter = _FakeFhirImporter(
          authorizationRecords: [
            _record(
              'fhir:lab-1',
              recordedAt: DateTime.utc(2026, 1, 5),
              source: 'SMART on FHIR (portal.example.org)',
            ),
          ],
          refreshRecords: const [],
        );
        final syncValues = _MemorySyncValueStore();
        final controller = HealthDataController(
          store: _MemoryRecordStore(),
          healthImporter: healthImporter,
          fhirImporter: fhirImporter,
          syncValueStore: syncValues,
        );
        addTearDown(controller.dispose);
        await controller.load();

        // 1. Successful manual health import
        await controller.importHealth(since: DateTime.utc(2025, 1, 1));
        expect(controller.importHistory, hasLength(1));
        expect(
          controller.importHistory.first.status,
          SourceImportOutcomeStatus.succeeded,
        );
        expect(controller.importHistory.first.fetchedCount, 1);
        expect(controller.importHistory.first.addedCount, 1);
        expect(controller.importHistory.first.isAutoSync, isFalse);

        // 2. Manual health import with 0 records logs empty outcome and throws StateError
        await expectLater(
          controller.importHealth(since: DateTime.utc(2025, 1, 1)),
          throwsA(isA<StateError>()),
        );
        expect(controller.importHistory, hasLength(2));
        expect(
          controller.importHistory.first.status,
          SourceImportOutcomeStatus.empty,
        );
        expect(controller.importHistory.first.isAutoSync, isFalse);

        // 3. Connect FHIR portal (succeeded) and sync FHIR portal (empty)
        await controller.connectFhir(
          baseUrl: 'https://portal.example.org/fhir/R4',
          clientId: 'client-123',
          rememberPortalForAutoSync: true,
        );
        expect(
          controller.importHistory.first.sourceKind,
          SourceImportSourceKind.fhirPortal,
        );
        expect(
          controller.importHistory.first.status,
          SourceImportOutcomeStatus.succeeded,
        );
        expect(
          controller.importHistory.first.sourceLabel,
          'SMART on FHIR (portal.example.org)',
        );

        await controller.syncFhir();
        expect(
          controller.importHistory.first.sourceKind,
          SourceImportSourceKind.fhirPortal,
        );
        expect(
          controller.importHistory.first.status,
          SourceImportOutcomeStatus.empty,
        );
        expect(controller.importHistory.first.isAutoSync, isTrue);

        // 4. Invalid FHIR JSON import records failed outcome
        await expectLater(
          controller.importFhirJson('{not-valid-json'),
          throwsA(isA<FormatException>()),
        );
        expect(
          controller.importHistory.first.sourceKind,
          SourceImportSourceKind.fhirJson,
        );
        expect(
          controller.importHistory.first.status,
          SourceImportOutcomeStatus.failed,
        );

        // 5. Clearing controller deletes history
        await controller.clear();
        expect(controller.importHistory, isEmpty);
      },
    );
  });

  group('ConnectionsPage coverage and activity UI', () {
    testWidgets(
      'displays per-source date spans, provenance disclaimer, and succeeded/empty/failed outcomes',
      (tester) async {
        final records = <HealthRecord>[
          _record(
            'health:1',
            recordedAt: DateTime(2025, 1, 10, 9),
            source: 'Apple Health',
          ),
          _record(
            'health:2',
            recordedAt: DateTime(2026, 3, 15, 9),
            source: 'Apple Health',
          ),
          _record(
            'fhir:1',
            recordedAt: DateTime(2025, 8, 22, 14),
            source: 'SMART on FHIR (epic.example.org)',
          ),
        ];

        final history = <SourceImportEvent>[
          SourceImportEvent(
            sourceKind: SourceImportSourceKind.healthPlatform,
            sourceLabel: 'Apple Health / Health Connect',
            timestamp: DateTime(2026, 3, 15, 10, 30),
            isAutoSync: false,
            status: SourceImportOutcomeStatus.succeeded,
            fetchedCount: 2,
            addedCount: 1,
            oldestRecordAt: DateTime(2025, 1, 10),
            newestRecordAt: DateTime(2026, 3, 15),
          ),
          SourceImportEvent(
            sourceKind: SourceImportSourceKind.fhirPortal,
            sourceLabel: 'SMART on FHIR (epic.example.org)',
            timestamp: DateTime(2026, 3, 16, 8, 0),
            isAutoSync: true,
            status: SourceImportOutcomeStatus.empty,
          ),
          SourceImportEvent(
            sourceKind: SourceImportSourceKind.fhirPortal,
            sourceLabel: 'SMART on FHIR (epic.example.org)',
            timestamp: DateTime(2026, 3, 14, 18, 15),
            isAutoSync: true,
            status: SourceImportOutcomeStatus.failed,
            errorSummary: 'Saved portal authorization expired.',
          ),
        ];

        final syncStore = _MemorySyncValueStore();
        final notificationManager = _FakeNotificationManager();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ConnectionsPage(
                busy: false,
                healthRecordCount: 2,
                fhirRecordCount: 1,
                records: records,
                importHistory: history,
                syncState: const ForegroundSyncState(
                  healthAutoSync: true,
                  fhirAutoSync: true,
                  fhirRefreshTokenAvailable: true,
                ),
                syncSettingsLoading: false,
                syncing: false,
                syncStatus: null,
                onHealthImport: () {},
                onFhirImport:
                    ({
                      required baseUrl,
                      required clientId,
                      required rememberPortalForAutoSync,
                      required onProgress,
                    }) async => null,
                onHealthAutoSyncChanged: (_) {},
                onFhirAutoSyncDisabled: () async {},
                onSyncNow: () {},
                onDeleteRecords: () async {},
                notificationManager: notificationManager,
                syncValueStore: syncStore,
                onProgress: (_) {},
                onOpenGuidelines: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('source-coverage-history-card')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('source-coverage-history-card')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('source-coverage-disclaimer')),
          findsOneWidget,
        );
        expect(
          find.textContaining('do not guarantee a complete medical history'),
          findsOneWidget,
        );

        // Verify observed date spans
        expect(
          find.text('Observed span: 2025-01-10 – 2026-03-15'),
          findsOneWidget,
        );
        expect(find.text('Observed date: 2025-08-22'), findsOneWidget);

        // Verify outcome badges and descriptions
        expect(find.text('Updated'), findsWidgets);
        expect(find.text('No records returned'), findsWidgets);
        expect(find.text('Failed'), findsOneWidget);
        expect(
          find.textContaining('Manual import · 2 returned (1 new)'),
          findsOneWidget,
        );
        expect(
          find.text('Auto sync · Checked source, 0 records returned'),
          findsOneWidget,
        );
        expect(
          find.text('Auto sync · Failed: Saved portal authorization expired.'),
          findsOneWidget,
        );
      },
    );
  });
}

HealthRecord _record(
  String id, {
  DateTime? recordedAt,
  String source = 'Apple Health',
}) {
  return HealthRecord(
    id: id,
    category: RecordCategory.lab,
    name: 'Hemoglobin A1c',
    value: '5.4',
    unit: '%',
    recordedAt: recordedAt ?? DateTime.utc(2026, 3, 1),
    source: source,
  );
}

class _MemoryRecordStore extends EncryptedRecordStore {
  List<HealthRecord> _records = const [];

  @override
  Future<List<HealthRecord>> load() async => _records;

  @override
  Future<void> save(
    List<HealthRecord> records, {
    ImportProgressCallback? onProgress,
  }) async {
    _records = List<HealthRecord>.unmodifiable(records);
    onProgress?.call(const ImportProgress(fraction: 1, message: 'Saved'));
  }

  @override
  Future<void> clear() async {
    _records = const [];
  }
}

class _MemorySyncValueStore implements SyncValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class _FakeHealthImporter extends HealthPlatformImporter {
  _FakeHealthImporter(this.responses);

  final List<List<HealthRecord>> responses;

  @override
  Future<List<HealthRecord>> importRecords({
    required DateTime since,
    ImportProgressCallback? onProgress,
  }) async {
    return responses.removeAt(0);
  }
}

class _FakeFhirImporter extends FhirPortalImporter {
  _FakeFhirImporter({
    required this.authorizationRecords,
    required this.refreshRecords,
  }) : super(
         client: MockClient((_) async => http.Response('', 500)),
         appAuth: const FlutterAppAuth(),
       );

  final List<HealthRecord> authorizationRecords;
  final List<HealthRecord> refreshRecords;

  @override
  Future<FhirPortalImportResult> authorizeAndImportLabResults({
    required String fhirBaseUrl,
    required String clientId,
    bool requestRefreshToken = false,
    DateTime? since,
    ImportProgressCallback? onProgress,
    List<String>? resourceTypes,
  }) async {
    return FhirPortalImportResult(
      records: authorizationRecords,
      patientId: 'patient-1',
      authorizationEndpoint: 'https://portal.example.org/authorize',
      tokenEndpoint: 'https://portal.example.org/token',
      refreshToken: requestRefreshToken ? 'refresh-token-1' : null,
    );
  }

  @override
  Future<FhirPortalImportResult> refreshAndImportLabResults({
    required String fhirBaseUrl,
    required String clientId,
    required String patientId,
    required String refreshToken,
    required String authorizationEndpoint,
    required String tokenEndpoint,
    DateTime? since,
    required Future<void> Function(String refreshToken) onRefreshTokenUpdated,
    ImportProgressCallback? onProgress,
    List<String>? resourceTypes,
  }) async {
    return FhirPortalImportResult(
      records: refreshRecords,
      patientId: patientId,
      authorizationEndpoint: authorizationEndpoint,
      tokenEndpoint: tokenEndpoint,
      refreshToken: refreshToken,
    );
  }
}

class _FakeNotificationManager implements ResultNotificationManager {
  ResultNotificationPreferences _prefs = const ResultNotificationPreferences();

  @override
  Future<ResultNotificationPreferences> loadPreferences() async => _prefs;

  @override
  Future<void> savePreferences(
    ResultNotificationPreferences preferences,
  ) async {
    _prefs = preferences;
  }

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> notifyForImport({
    required List<HealthRecord> newlyImported,
    required List<HealthRecord> allRecords,
  }) async {}
}
