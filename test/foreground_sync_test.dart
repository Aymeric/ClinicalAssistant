import 'dart:async';
import 'dart:io';

import 'package:clinical_assistant/data/encrypted_record_store.dart';
import 'package:clinical_assistant/integrations/fhir_portal_importer.dart';
import 'package:clinical_assistant/integrations/health_platform_importer.dart';
import 'package:clinical_assistant/main.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/sync/foreground_sync_state.dart';
import 'package:clinical_assistant/sync/import_progress.dart';
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
      ))
          .map((record) => record.id),
      ['health:first'],
    );
    expect(await controller.syncHealth(), isEmpty);
    expect(progress, contains(0.45));
    expect(progress.last, 1);

    final state = await controller.loadForegroundSyncState();
    expect(state.healthAutoSync, isTrue);
    expect(state.lastHealthSyncAt, isNotNull);
    expect(
      DateTime.now().difference(healthImporter.sinceValues.first),
      greaterThan(const Duration(days: 29)),
    );
    expect(
      DateTime.now().difference(healthImporter.sinceValues.first),
      lessThan(const Duration(days: 31)),
    );
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
  Future<void> save(List<HealthRecord> records) async {
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
  _FakeHealthImporter(this.responses);

  final List<List<HealthRecord>> responses;
  final sinceValues = <DateTime>[];

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
  })  : _refreshRecords = refreshRecords ?? [_record('fhir:new')],
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
      refreshToken:
          requestRefreshToken && issueRefreshToken ? 'initial-refresh' : null,
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
    required DateTime since,
    required Future<void> Function(String refreshToken) onRefreshTokenUpdated,
    ImportProgressCallback? onProgress,
    List<String>? resourceTypes,
  }) async {
    refreshCount++;
    lastRefreshToken = refreshToken;
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
