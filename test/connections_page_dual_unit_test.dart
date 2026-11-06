import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/notifications/result_notification_manager.dart';
import 'package:clinical_assistant/notifications/result_notification_preferences.dart';
import 'package:clinical_assistant/sync/foreground_sync_state.dart';
import 'package:clinical_assistant/terminology/clinical_unit_converter.dart';
import 'package:clinical_assistant/ui/connections/connections_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

class _MemorySyncValueStore implements SyncValueStore {
  final _map = <String, String>{};
  @override
  Future<void> delete(String key) async => _map.remove(key);
  @override
  Future<String?> read(String key) async => _map[key];
  @override
  Future<void> write(String key, String value) async => _map[key] = value;
}

void main() {
  testWidgets(
    'ConnectionsPage renders Preferred Lab Unit System Card and toggles system',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      ClinicalUnitSystem? selectedSystem;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionsPage(
              busy: false,
              healthRecordCount: 0,
              fhirRecordCount: 0,
              records: const [],
              importHistory: const [],
              syncState: null,
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
              notificationManager: _FakeNotificationManager(),
              syncValueStore: _MemorySyncValueStore(),
              onProgress: (_) {},
              onOpenGuidelines: () {},
              preferredUnitSystem: ClinicalUnitSystem.usConventional,
              onPreferredUnitSystemChanged: (system) => selectedSystem = system,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final cardFinder = find.byKey(
        const ValueKey('preferred-unit-system-card'),
      );
      await tester.scrollUntilVisible(
        cardFinder,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      // Verify card is rendered
      expect(cardFinder, findsOneWidget);
      expect(find.text('Preferred Lab Unit System'), findsOneWidget);

      // Tap International SI option
      final siButton = find.textContaining('International SI');
      expect(siButton, findsOneWidget);
      await tester.tap(siButton);
      await tester.pumpAndSettle();

      expect(selectedSystem, equals(ClinicalUnitSystem.internationalSi));
    },
  );
}
