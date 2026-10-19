import 'package:clinical_assistant/integrations/fhir_provider_presets.dart';
import 'package:clinical_assistant/sync/foreground_sync_state.dart';
import 'package:clinical_assistant/sync/import_progress.dart';
import 'package:clinical_assistant/ui/connections/connections_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSyncValueStore implements SyncValueStore {
  final Map<String, String> values = {};

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

void main() {
  testWidgets('FhirConnectionForm displays preset selector and populates values', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final syncStore = _FakeSyncValueStore();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FhirConnectionForm(
              busy: false,
              importedCount: 0,
              autoSyncConfigured: false,
              syncValueStore: syncStore,
              connected: false,
              onConnect: ({
                required String baseUrl,
                required String clientId,
                required bool rememberPortalForAutoSync,
                required ImportProgressCallback onProgress,
              }) async => null,
              onProgress: (_) {},
              onDisableAutoSync: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify redirect URI card is visible
    expect(find.text('OAuth 2.0 Redirect URI'), findsOneWidget);
    expect(find.text(FhirProviderPreset.appRedirectUri), findsOneWidget);

    // Verify preset dropdown is present
    final dropdownFinder = find.byKey(const ValueKey('fhir-preset-dropdown'));
    expect(dropdownFinder, findsOneWidget);

    // Tap dropdown and select Epic on FHIR Sandbox
    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();

    final epicOptionFinder = find.text('Epic on FHIR Developer Sandbox').last;
    await tester.tap(epicOptionFinder);
    await tester.pumpAndSettle();

    // Verify base URL is populated with Epic sandbox URL
    expect(
      find.text('https://fhir.epic.com/interconnect-fhir-oauth/api/FHIR/R4'),
      findsOneWidget,
    );

    // Verify instructions card appears
    expect(find.textContaining('Register at fhir.epic.com'), findsOneWidget);

    // Tap dropdown and select SMART Health IT Sandbox
    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();

    final smartOptionFinder =
        find.text('SMART Health IT Sample Portal (R4)').last;
    await tester.tap(smartOptionFinder);
    await tester.pumpAndSettle();

    // Verify base URL and default client ID are populated
    expect(
      find.text('https://launch.smarthealthit.org/v/r4/fhir'),
      findsOneWidget,
    );
    expect(find.text('clinical_assistant_smart_client'), findsOneWidget);
  });
}
