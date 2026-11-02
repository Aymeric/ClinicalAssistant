import 'package:clinical_assistant/data/critical_safety_preferences.dart';
import 'package:clinical_assistant/sync/foreground_sync_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemorySyncValueStore implements SyncValueStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);
}

void main() {
  group('CriticalSafetyPreferences', () {
    late _InMemorySyncValueStore store;
    late CriticalSafetyPreferences prefs;

    setUp(() {
      store = _InMemorySyncValueStore();
      prefs = CriticalSafetyPreferences(storage: store);
    });

    test('defaults to athletic profile (< 35 bpm threshold)', () async {
      final profile = await prefs.getProfile();
      expect(profile, RestingHeartRateProfile.athletic);
      expect(profile.thresholdBpm, 35.0);
    });

    test('persists and restores selected profile', () async {
      await prefs.setProfile(RestingHeartRateProfile.standard);
      expect(await prefs.getProfile(), RestingHeartRateProfile.standard);
      expect((await prefs.getProfile()).thresholdBpm, 40.0);

      await prefs.setProfile(RestingHeartRateProfile.elite);
      expect(await prefs.getProfile(), RestingHeartRateProfile.elite);
      expect((await prefs.getProfile()).thresholdBpm, 30.0);
    });

    test(
      'falls back safely to default athletic profile on invalid stored value',
      () async {
        await store.write(
          'critical_safety_rhr_profile_v1',
          'unknown_invalid_profile',
        );
        expect(await prefs.getProfile(), RestingHeartRateProfile.athletic);
      },
    );
  });
}
