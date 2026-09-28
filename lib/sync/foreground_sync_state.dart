import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ForegroundSyncState {
  const ForegroundSyncState({
    this.healthAutoSync = false,
    this.fhirAutoSync = false,
    this.fhirRefreshTokenAvailable = false,
    this.lastHealthSyncAt,
    this.lastFhirSyncAt,
  });

  final bool healthAutoSync;
  final bool fhirAutoSync;
  final bool fhirRefreshTokenAvailable;
  final DateTime? lastHealthSyncAt;
  final DateTime? lastFhirSyncAt;

  bool get hasAutoSync => healthAutoSync || fhirAutoSync;
}

abstract interface class SyncValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class SecureSyncValueStore implements SyncValueStore {
  SecureSyncValueStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
