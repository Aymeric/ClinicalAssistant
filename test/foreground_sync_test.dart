import 'dart:async';
import 'dart:io';

import 'package:clinical_assistant/data/encrypted_record_store.dart';
import 'package:clinical_assistant/integrations/fhir_portal_importer.dart';
import 'package:clinical_assistant/integrations/health_platform_importer.dart';
import 'package:clinical_assistant/main.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/sync/foreground_sync_state.dart';
import 'package:clinical_assistant/sync/import_progress.dart';
import 'package:clinical_assistant/ui/connections/connections_page.dart';
import 'package:clinical_assistant/ui/shared/record_widgets.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('health auto-sync stores a successful incremental checkpoint', () async {
    final healthImporter = _FakeHealthImporter([
      [_record('health:first')],
      const [],
    ]);
    final syncValues = _MemorySyncValueStore();
    final controller = HealthDataController(
      store: _MemoryRecordStore(),
      healthImporter: healthImporter,
      fhirImporter: _FakeFhirImporter(),
      syncValueStore: syncValues,
    );
    addTearDown(controller.dispose);
    await controller.load();
    await controller.setHealthAutoSync(true);

    final progress = <double>[];
    expect(
      (await controller.syncHealth(
        onProgress: (value) => progress.add(value.fraction),
      )).map((record) => record.id),
      ['health:first'],
    );
    expect(await controller.syncHealth(), isEmpty);
    expect(progress, contains(0.45));
    expect(progress.last, 1);

    final state = await controller.loadForegroundSyncState();
    expect(state.healthAutoSync, isTrue);
    expect(state.lastHealthSyncAt, isNotNull);
    expect(healthImporter.sinceValues.first.year, lessThanOrEqualTo(1900));
    expect(
      DateTime.now().difference(healthImporter.sinceValues.last),
      greaterThan(const Duration(days: 2)),
    );
    expect(
      DateTime.now().difference(healthImporter.sinceValues.last),
      lessThan(const Duration(days: 4)),
    );
  });

  test(
    'health sync uses change token for incremental sync on Android and updates next token',
    () async {
      final healthImporter = _FakeHealthImporter(
        [
          [_record('health:initial-1')],
          [_record('health:unexpected-range')],
        ],
        changesTokenValue: 'token-1',
        changesResults: [
          HealthChangesResult(
            records: [_record('health:delta-2')],
            nextChangesToken: 'token-2',
          ),
        ],
      );
      final syncValues = _MemorySyncValueStore();
      final controller = HealthDataController(
        store: _MemoryRecordStore(),
        healthImporter: healthImporter,
        fhirImporter: _FakeFhirImporter(),
        syncValueStore: syncValues,
      );
      addTearDown(controller.dispose);
      await controller.load();

      // Initial sync (no token exists yet) performs range import and saves token-1
      final initial = await controller.syncHealth(isAndroid: true);
      expect(initial.map((r) => r.id), ['health:initial-1']);
      expect(syncValues.values['health_sync_changes_token_v1'], 'token-1');
      expect(healthImporter.sinceValues.length, 1);

      // Incremental sync uses changesToken instead of range querying
      final incremental = await controller.syncHealth(isAndroid: true);
      expect(incremental.map((r) => r.id), ['health:delta-2']);
      expect(syncValues.values['health_sync_changes_token_v1'], 'token-2');
      expect(healthImporter.changesTokenCalls, ['token-1']);
      // Verify no additional range query was executed
      expect(healthImporter.sinceValues.length, 1);

      // Verify records are merged
      expect(
        controller.records.map((r) => r.id),
        containsAll(['health:initial-1', 'health:delta-2']),
      );
    },
  );

  test(
    'resetHealthSyncAnchor clears tokens without deleting stored records',
    () async {
      final healthImporter = _FakeHealthImporter([
        [_record('health:record-1')],
        [_record('health:record-2')],
      ], changesTokenValue: 'token-1');
      final syncValues = _MemorySyncValueStore();
      final store = _MemoryRecordStore();
      final controller = HealthDataController(
        store: store,
        healthImporter: healthImporter,
        fhirImporter: _FakeFhirImporter(),
        syncValueStore: syncValues,
      );
      addTearDown(controller.dispose);
      await controller.load();

      await controller.syncHealth(isAndroid: true);
      expect(controller.records.length, 1);

      var state = await controller.loadForegroundSyncState();
      expect(state.hasHealthSyncAnchor, isTrue);
      expect(
        syncValues.values.containsKey('health_sync_changes_token_v1'),
        isTrue,
      );
      expect(syncValues.values.containsKey('last_health_sync_v1'), isTrue);

      // Reset the anchor
      await controller.resetHealthSyncAnchor();

      // Anchor flags and keys are cleared
      state = await controller.loadForegroundSyncState();
      expect(state.hasHealthSyncAnchor, isFalse);
      expect(state.lastHealthSyncAt, isNull);
      expect(
        syncValues.values.containsKey('health_sync_changes_token_v1'),
        isFalse,
      );
      expect(syncValues.values.containsKey('last_health_sync_v1'), isFalse);

      // But existing records in memory and database are PRESERVED!
      expect(controller.records.length, 1);
      expect(controller.records.first.id, 'health:record-1');
      expect((await store.load()).map((r) => r.id), ['health:record-1']);

      // Next sync starts range search from scratch (year 1900) without token
      await controller.syncHealth(isAndroid: true);
      expect(healthImporter.sinceValues.last.year, lessThanOrEqualTo(1900));
      expect(controller.records.length, 2);
    },
  );

  test(
    'FHIR sync stores, rotates, and removes opted-in refresh credentials',
    () async {
      final syncValues = _MemorySyncValueStore();
      final fhirImporter = _FakeFhirImporter();
      final controller = HealthDataController(
        store: _MemoryRecordStore(),
        fhirImporter: fhirImporter,
        syncValueStore: syncValues,
      );
      addTearDown(controller.dispose);
      await controller.load();

      final connection = await controller.connectFhir(
        baseUrl: 'https://portal.example/fhir',
        clientId: 'registered-client',
        rememberPortalForAutoSync: true,
      );
      expect(connection.autoSyncEnabled, isTrue);
      expect(connection.autoSyncUnavailable, isFalse);
      expect(syncValues.values['fhir_refresh_token_v1'], 'initial-refresh');

      expect((await controller.syncFhir()).map((record) => record.id), [
        'fhir:new',
      ]);
      expect(fhirImporter.lastRefreshToken, 'initial-refresh');
      expect(syncValues.values['fhir_refresh_token_v1'], 'rotated-refresh');

      final state = await controller.loadForegroundSyncState();
      expect(state.fhirAutoSync, isTrue);
      expect(state.fhirRefreshTokenAvailable, isTrue);
      expect(state.lastFhirSyncAt, isNotNull);

      await controller.connectFhir(
        baseUrl: 'https://another-portal.example/fhir',
        clientId: 'registered-client',
      );
      final disabledState = await controller.loadForegroundSyncState();
      expect(disabledState.fhirAutoSync, isFalse);
      expect(disabledState.fhirRefreshTokenAvailable, isFalse);
      expect(syncValues.values.containsKey('fhir_refresh_token_v1'), isFalse);
    },
  );

  test(
    'FHIR sync downloads all history on initial sync and uses checkpoint thereafter',
    () async {
      final syncValues = _MemorySyncValueStore()
        ..values.addAll({
          'fhir_base_url_v1': 'https://portal.example/fhir',
          'fhir_client_id_v1': 'registered-client',
          'fhir_refresh_token_v1': 'saved-refresh-token',
          'fhir_patient_id_v1': 'patient-7',
          'fhir_authorization_endpoint_v1':
              'https://login.portal.example/authorize',
          'fhir_token_endpoint_v1': 'https://login.portal.example/token',
        });
      final fhirImporter = _FakeFhirImporter(
        refreshRecords: [_record('fhir:initial')],
      );
      final controller = HealthDataController(
        store: _MemoryRecordStore(),
        fhirImporter: fhirImporter,
        syncValueStore: syncValues,
      );
      addTearDown(controller.dispose);
      await controller.load();

      // Initial sync: lastFhirSyncKey is null -> since is null (all history)
      final initialRecords = await controller.syncFhir();
      expect(initialRecords.map((r) => r.id), ['fhir:initial']);
      expect(fhirImporter.sinceValues.first, isNull);

      // Subsequent sync: lastFhirSyncKey is set -> since has 3-day overlap checkpoint
      await controller.syncFhir();
      expect(fhirImporter.sinceValues.length, 2);
      expect(fhirImporter.sinceValues.last, isNotNull);
      expect(
        DateTime.now().difference(fhirImporter.sinceValues.last!),
        lessThan(const Duration(days: 4)),
      );
    },
  );

  test(
    'FHIR connection leaves auto-sync off when no refresh token is issued',
    () async {
      final syncValues = _MemorySyncValueStore();
      final controller = HealthDataController(
        store: _MemoryRecordStore(),
        fhirImporter: _FakeFhirImporter(issueRefreshToken: false),
        syncValueStore: syncValues,
      );
      addTearDown(controller.dispose);
      await controller.load();

      final outcome = await controller.connectFhir(
        baseUrl: 'https://portal.example/fhir',
        clientId: 'registered-client',
        rememberPortalForAutoSync: true,
      );

      expect(outcome.autoSyncEnabled, isFalse);
      expect(outcome.autoSyncUnavailable, isTrue);
      expect(
        (await controller.loadForegroundSyncState()).fhirAutoSync,
        isFalse,
      );
    },
  );

  test(
    'deleting local records disables sync and clears FHIR credentials',
    () async {
      final syncValues = _MemorySyncValueStore();
      final recordStore = _MemoryRecordStore();
      final controller = HealthDataController(
        store: recordStore,
        fhirImporter: _FakeFhirImporter(),
        syncValueStore: syncValues,
      );
      addTearDown(controller.dispose);
      await controller.load();
      await controller.setHealthAutoSync(true);
      await controller.connectFhir(
        baseUrl: 'https://portal.example/fhir',
        clientId: 'registered-client',
        rememberPortalForAutoSync: true,
      );

      await controller.clear();

      final state = await controller.loadForegroundSyncState();
      expect(controller.records, isEmpty);
      expect(state.healthAutoSync, isFalse);
      expect(state.fhirAutoSync, isFalse);
      expect(state.fhirRefreshTokenAvailable, isFalse);
      expect(state.lastHealthSyncAt, isNull);
      expect(state.lastFhirSyncAt, isNull);
      expect(syncValues.values.containsKey('fhir_refresh_token_v1'), isFalse);
    },
  );

  testWidgets('syncs on launch and rate-limits quick foreground returns', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final syncValues = _MemorySyncValueStore()
      ..values.addAll({
        'fhir_auto_sync_v1': 'true',
        'fhir_base_url_v1': 'https://portal.example/fhir',
        'fhir_client_id_v1': 'registered-client',
        'fhir_refresh_token_v1': 'saved-refresh-token',
        'fhir_patient_id_v1': 'patient-7',
        'fhir_authorization_endpoint_v1':
            'https://login.portal.example/authorize',
        'fhir_token_endpoint_v1': 'https://login.portal.example/token',
      });
    final fhirImporter = _FakeFhirImporter(refreshRecords: const []);
    final controller = HealthDataController(
      store: _MemoryRecordStore(),
      fhirImporter: fhirImporter,
      syncValueStore: syncValues,
    );
    await tester.pumpWidget(
      MaterialApp(home: HealthHome(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(fhirImporter.refreshCount, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(fhirImporter.refreshCount, 1);

    await tester.tap(find.byIcon(Icons.hub_outlined));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sync enabled sources now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sync enabled sources now'));
    await tester.pumpAndSettle();
    expect(fhirImporter.refreshCount, 2);
  });

  testWidgets('portal auto-sync requires an explicit checkbox opt-in', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final syncValues = _MemorySyncValueStore();
    final authorizationGate = Completer<void>();
    final controller = HealthDataController(
      store: _MemoryRecordStore(),
      fhirImporter: _FakeFhirImporter(
        authorizationRecords: const [],
        authorizationGate: authorizationGate,
      ),
      syncValueStore: syncValues,
    );
    await tester.pumpWidget(
      MaterialApp(home: HealthHome(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.hub_outlined));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextFormField).first);
    await tester.enterText(
      find.byType(TextFormField).first,
      'https://portal.example/fhir',
    );
    await tester.enterText(
      find.byType(TextFormField).last,
      'registered-client',
    );
    await tester.ensureVisible(find.text('Automatically sync this portal'));
    final autoSyncTile = find.widgetWithText(
      CheckboxListTile,
      'Automatically sync this portal',
    );
    expect(tester.widget<CheckboxListTile>(autoSyncTile).onChanged, isNotNull);
    await tester.tap(
      find.descendant(of: autoSyncTile, matching: find.byType(Checkbox)),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(
              CheckboxListTile,
              'Automatically sync this portal',
            ),
          )
          .value,
      isTrue,
    );

    expect(syncValues.values['fhir_auto_sync_v1'], isNull);
    await tester.ensureVisible(find.text('Authorize and import labs'));
    await tester.tap(find.text('Authorize and import labs'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      closeTo(0.54, 0.001),
    );
    authorizationGate.complete();
    await tester.pumpAndSettle();

    expect(syncValues.values['fhir_auto_sync_v1'], 'true');
    expect(syncValues.values['fhir_refresh_token_v1'], 'initial-refresh');
    expect(syncValues.values['fhir_patient_id_v1'], 'patient-7');
  });

  testWidgets(
    'renders reset anchor buttons when anchor is present and triggers reset',
    (tester) async {
      var resetCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  ForegroundSyncPanel(
                    state: const ForegroundSyncState(
                      healthAutoSync: true,
                      hasHealthSyncAnchor: true,
                    ),
                    loading: false,
                    syncing: false,
                    healthSyncAvailable: true,
                    status: null,
                    onHealthAutoSyncChanged: (_) {},
                    onSyncNow: () {},
                    onResetHealthSyncAnchor: () {
                      resetCalled = true;
                    },
                  ),
                  SourcePanel(
                    icon: Icons.favorite,
                    title: 'Health Connect',
                    description: 'Test description',
                    count: 5,
                    connected: true,
                    busy: false,
                    hasAnchor: true,
                    buttonLabel: 'Connect',
                    onPressed: () {},
                    onResetAnchor: () {
                      resetCalled = true;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('reset-sync-anchor-foreground-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('reset-health-sync-anchor-button')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('reset-sync-anchor-foreground-button')),
      );
      await tester.pumpAndSettle();
      expect(resetCalled, isTrue);
    },
  );
}

HealthRecord _record(String id) => HealthRecord(
  id: id,
  name: 'Glucose',
  value: '100',
  unit: 'mg/dL',
  recordedAt: DateTime.utc(2026, 9, 20),
  category: RecordCategory.lab,
  source: 'Example portal',
);

class _MemoryRecordStore extends EncryptedRecordStore {
  _MemoryRecordStore() : super(directory: Directory.systemTemp);

  List<HealthRecord> records = const [];

  @override
  Future<List<HealthRecord>> load() async => records;

  @override
  Future<void> save(
    List<HealthRecord> records, {
    ImportProgressCallback? onProgress,
  }) async {
    this.records = records;
  }

  @override
  Future<void> clear() async {
    records = const [];
  }
}

class _MemorySyncValueStore implements SyncValueStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _FakeHealthImporter extends HealthPlatformImporter {
  _FakeHealthImporter(
    this.responses, {
    this.changesTokenValue,
    List<HealthChangesResult>? changesResults,
  }) : changesResults = changesResults != null
           ? List<HealthChangesResult>.from(changesResults)
           : <HealthChangesResult>[];

  final List<List<HealthRecord>> responses;
  final sinceValues = <DateTime>[];
  String? changesTokenValue;
  final List<HealthChangesResult> changesResults;
  final changesTokenCalls = <String>[];
  var getChangesTokenCallCount = 0;

  @override
  Future<String?> getChangesToken({bool? isAndroid}) async {
    getChangesTokenCallCount++;
    return changesTokenValue;
  }

  @override
  Future<HealthChangesResult?> importChanges({
    required String changesToken,
    ImportProgressCallback? onProgress,
    bool? isAndroid,
  }) async {
    changesTokenCalls.add(changesToken);
    onProgress?.call(
      const ImportProgress(fraction: 0.5, message: 'Reading test changes'),
    );
    if (changesResults.isNotEmpty) {
      return changesResults.removeAt(0);
    }
    return null;
  }

  @override
  Future<List<HealthRecord>> importRecords({
    required DateTime since,
    ImportProgressCallback? onProgress,
  }) async {
    sinceValues.add(since);
    onProgress?.call(
      const ImportProgress(fraction: 0.5, message: 'Reading test records'),
    );
    return responses.removeAt(0);
  }
}

class _FakeFhirImporter extends FhirPortalImporter {
  _FakeFhirImporter({
    this.issueRefreshToken = true,
    List<HealthRecord>? refreshRecords,
    List<HealthRecord>? authorizationRecords,
    this.authorizationGate,
  }) : _refreshRecords = refreshRecords ?? [_record('fhir:new')],
       _authorizationRecords =
           authorizationRecords ?? [_record('fhir:existing')],
       super(
         client: MockClient((_) async => http.Response('', 500)),
         appAuth: const FlutterAppAuth(),
       );

  final bool issueRefreshToken;
  final List<HealthRecord> _refreshRecords;
  final List<HealthRecord> _authorizationRecords;
  final Completer<void>? authorizationGate;
  var refreshCount = 0;
  String? lastRefreshToken;
  final sinceValues = <DateTime?>[];

  @override
  Future<FhirPortalImportResult> authorizeAndImportLabResults({
    required String fhirBaseUrl,
    required String clientId,
    bool requestRefreshToken = false,
    DateTime? since,
    ImportProgressCallback? onProgress,
    List<String>? resourceTypes,
  }) async {
    onProgress?.call(
      const ImportProgress(fraction: 0.6, message: 'Downloading test labs'),
    );
    await authorizationGate?.future;
    return FhirPortalImportResult(
      records: _authorizationRecords,
      patientId: 'patient-7',
      authorizationEndpoint: 'https://login.portal.example/authorize',
      tokenEndpoint: 'https://login.portal.example/token',
      refreshToken: requestRefreshToken && issueRefreshToken
          ? 'initial-refresh'
          : null,
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
    refreshCount++;
    lastRefreshToken = refreshToken;
    sinceValues.add(since);
    await onRefreshTokenUpdated('rotated-refresh');
    onProgress?.call(
      const ImportProgress(fraction: 0.6, message: 'Downloading test labs'),
    );
    return FhirPortalImportResult(
      records: _refreshRecords,
      patientId: patientId,
      authorizationEndpoint: authorizationEndpoint,
      tokenEndpoint: tokenEndpoint,
      refreshToken: 'rotated-refresh',
    );
  }
}
