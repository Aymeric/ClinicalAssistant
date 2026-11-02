import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../sync/foreground_sync_state.dart';

/// Clinical profiles for resting heart rate emergency alert thresholds.
enum RestingHeartRateProfile {
  athletic(
    title: 'Athletic / Active',
    description:
        'Calibrated for active individuals, runners, and athletes with a low physiological baseline (alert below 35 bpm).',
    thresholdBpm: 35.0,
  ),
  standard(
    title: 'Standard Adult',
    description:
        'Standard clinical consensus threshold for non-athletic adults (alert below 40 bpm).',
    thresholdBpm: 40.0,
  ),
  elite(
    title: 'Elite Endurance',
    description:
        'For high-volume endurance athletes with nocturnal resting heart rates dipping into the 30s (alert below 30 bpm).',
    thresholdBpm: 30.0,
  );

  const RestingHeartRateProfile({
    required this.title,
    required this.description,
    required this.thresholdBpm,
  });

  final String title;
  final String description;
  final double thresholdBpm;
}

/// Persists and retrieves user preferences for critical safety alert baselines.
class CriticalSafetyPreferences {
  CriticalSafetyPreferences({
    SyncValueStore? storage,
    FlutterSecureStorage? secureStorage,
  }) : _storage =
           storage ??
           SecureSyncValueStore(
             storage: secureStorage ?? const FlutterSecureStorage(),
           );

  static const _profileKey = 'critical_safety_rhr_profile_v1';
  final SyncValueStore _storage;

  Future<RestingHeartRateProfile> getProfile() async {
    final raw = await _storage.read(_profileKey);
    if (raw == null || raw.isEmpty) return RestingHeartRateProfile.athletic;
    for (final p in RestingHeartRateProfile.values) {
      if (p.name == raw) return p;
    }
    return RestingHeartRateProfile.athletic;
  }

  Future<void> setProfile(RestingHeartRateProfile profile) async {
    await _storage.write(_profileKey, profile.name);
  }

  Future<double> getThreshold() async {
    final profile = await getProfile();
    return profile.thresholdBpm;
  }
}
