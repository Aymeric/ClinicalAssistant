import 'package:clinical_assistant/controllers/health_data_controller.dart';
import 'package:clinical_assistant/data/clinical_unit_preferences.dart';
import 'package:clinical_assistant/sync/foreground_sync_state.dart';
import 'package:clinical_assistant/terminology/clinical_unit_converter.dart';
import 'package:flutter_test/flutter_test.dart';

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
  group('ClinicalUnitPreferences & HealthDataController Unit Preferences', () {
    late _MemorySyncValueStore store;
    late ClinicalUnitPreferences prefs;

    setUp(() {
      store = _MemorySyncValueStore();
      prefs = ClinicalUnitPreferences(storage: store);
    });

    test('defaults to US Conventional when no preference is saved', () async {
      final initial = await prefs.getPreferredSystem();
      expect(initial, equals(ClinicalUnitSystem.usConventional));
    });

    test('saves and loads International SI system', () async {
      await prefs.setPreferredSystem(ClinicalUnitSystem.internationalSi);
      final loaded = await prefs.getPreferredSystem();
      expect(loaded, equals(ClinicalUnitSystem.internationalSi));
    });

    test(
      'HealthDataController updates preferred unit system and notifies listeners',
      () async {
        final controller = HealthDataController(
          syncValueStore: store,
          unitPreferences: prefs,
        );

        expect(
          controller.preferredUnitSystem,
          equals(ClinicalUnitSystem.usConventional),
        );

        var notified = false;
        controller.addListener(() => notified = true);

        await controller.setPreferredUnitSystem(
          ClinicalUnitSystem.internationalSi,
        );
        expect(
          controller.preferredUnitSystem,
          equals(ClinicalUnitSystem.internationalSi),
        );
        expect(notified, isTrue);

        final persisted = await prefs.getPreferredSystem();
        expect(persisted, equals(ClinicalUnitSystem.internationalSi));
      },
    );
  });
}
