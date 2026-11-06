import '../sync/foreground_sync_state.dart';
import '../terminology/clinical_unit_converter.dart';

/// Persists the user's preferred clinical unit system (US Conventional vs International SI)
/// securely in local storage via [SyncValueStore].
class ClinicalUnitPreferences {
  ClinicalUnitPreferences({required SyncValueStore storage})
    : _storage = storage;

  static const _keyName = 'clinical_assistant_preferred_unit_system_v1';
  final SyncValueStore _storage;

  /// Retrieves the saved unit system, defaulting to [ClinicalUnitSystem.usConventional].
  Future<ClinicalUnitSystem> getPreferredSystem() async {
    final raw = await _storage.read(_keyName);
    if (raw == null || raw.isEmpty) {
      return ClinicalUnitSystem.usConventional;
    }
    return switch (raw.trim()) {
      'si' || 'internationalSi' => ClinicalUnitSystem.internationalSi,
      _ => ClinicalUnitSystem.usConventional,
    };
  }

  /// Saves the preferred unit system.
  Future<void> setPreferredSystem(ClinicalUnitSystem system) async {
    final val = switch (system) {
      ClinicalUnitSystem.usConventional => 'us',
      ClinicalUnitSystem.internationalSi => 'si',
    };
    await _storage.write(_keyName, val);
  }

  /// Resets the preference to default.
  Future<void> clear() async {
    await _storage.delete(_keyName);
  }
}
