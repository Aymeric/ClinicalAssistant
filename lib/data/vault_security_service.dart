import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../sync/foreground_sync_state.dart';

enum AutoLockTimeout {
  immediate('Immediately', Duration.zero),
  oneMinute('1 minute', Duration(minutes: 1)),
  fiveMinutes('5 minutes', Duration(minutes: 5)),
  fifteenMinutes('15 minutes', Duration(minutes: 15)),
  never('Never', null);

  const AutoLockTimeout(this.label, this.duration);
  final String label;
  final Duration? duration;

  static AutoLockTimeout fromString(String? value) {
    return AutoLockTimeout.values.firstWhere(
      (element) => element.name == value,
      orElse: () => AutoLockTimeout.immediate,
    );
  }
}

class VaultSecurityService {
  VaultSecurityService({
    SyncValueStore? storage,
    FlutterSecureStorage? secureStorage,
    Pbkdf2? pbkdf2,
    Pbkdf2? legacyPbkdf2,
  }) : _storage =
           storage ??
           SecureSyncValueStore(
             storage: secureStorage ?? const FlutterSecureStorage(),
           ),
       _pbkdf2 =
           pbkdf2 ??
           Pbkdf2(
             macAlgorithm: Hmac.sha256(),
             // Security: 100,000 PBKDF2-HMAC-SHA256 iterations strengthens PIN key derivation
             // against offline brute-force attacks on short PINs, aligning with OWASP guidelines.
             iterations: 100000,
             bits: 256,
           ),
       _legacyPbkdf2 =
           legacyPbkdf2 ??
           Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 10000, bits: 256);

  static const _pinHashKey = 'vault_pin_hash_v1';
  static const _pinSaltKey = 'vault_pin_salt_v1';
  static const _timeoutKey = 'vault_autolock_timeout_v1';

  final SyncValueStore _storage;
  final Pbkdf2 _pbkdf2;
  final Pbkdf2 _legacyPbkdf2;

  bool _isLocked = false;
  DateTime? _backgroundedAt;
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  bool get isLocked => _isLocked;
  int get failedAttempts => _failedAttempts;

  int get remainingLockoutSeconds {
    if (_lockoutUntil == null) return 0;
    final diff = _lockoutUntil!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  bool get isRateLimited => remainingLockoutSeconds > 0;

  Future<bool> isPinConfigured() async {
    try {
      final hash = await _storage.read(_pinHashKey);
      return hash != null && hash.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> setPin(String pin) async {
    if (pin.length < 4) {
      throw ArgumentError('PIN must be at least 4 digits');
    }
    final salt = _generateSalt();
    final hash = await _hashPin(pin, salt);
    await _storage.write(_pinSaltKey, base64Encode(salt));
    await _storage.write(_pinHashKey, base64Encode(hash));
    _failedAttempts = 0;
    _lockoutUntil = null;
    _isLocked = false;
  }

  Future<bool> verifyPin(String enteredPin) async {
    if (isRateLimited) {
      return false;
    }

    try {
      final storedSaltBase64 = await _storage.read(_pinSaltKey);
      final storedHashBase64 = await _storage.read(_pinHashKey);

      if (storedSaltBase64 == null || storedHashBase64 == null) {
        return false;
      }

      final salt = base64Decode(storedSaltBase64);
      final expectedHash = base64Decode(storedHashBase64);
      final actualHash = await _hashPin(enteredPin, salt);

      var isValid = _constantTimeCompare(expectedHash, actualHash);
      if (!isValid) {
        // Fallback for legacy PINs hashed with 10,000 iterations
        final legacyHash = await _hashPinWithKdf(
          _legacyPbkdf2,
          enteredPin,
          salt,
        );
        if (_constantTimeCompare(expectedHash, legacyHash)) {
          isValid = true;
          // Upgrade stored PIN hash transparently to 100,000 iterations
          final newSalt = _generateSalt();
          final newHash = await _hashPin(enteredPin, newSalt);
          await _storage.write(_pinSaltKey, base64Encode(newSalt));
          await _storage.write(_pinHashKey, base64Encode(newHash));
        }
      }

      if (isValid) {
        _failedAttempts = 0;
        _lockoutUntil = null;
        _isLocked = false;
        return true;
      } else {
        _failedAttempts++;
        if (_failedAttempts >= 5) {
          _lockoutUntil = DateTime.now().add(const Duration(seconds: 30));
        }
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  Future<bool> changePin(String oldPin, String newPin) async {
    final isOldValid = await verifyPin(oldPin);
    if (!isOldValid) return false;
    await setPin(newPin);
    return true;
  }

  Future<bool> removePin(String currentPin) async {
    final isOldValid = await verifyPin(currentPin);
    if (!isOldValid) return false;
    try {
      await _storage.delete(_pinHashKey);
      await _storage.delete(_pinSaltKey);
    } catch (_) {}
    _failedAttempts = 0;
    _lockoutUntil = null;
    _isLocked = false;
    return true;
  }

  Future<AutoLockTimeout> getTimeout() async {
    try {
      final val = await _storage.read(_timeoutKey);
      return AutoLockTimeout.fromString(val);
    } catch (_) {
      return AutoLockTimeout.immediate;
    }
  }

  Future<void> setTimeout(AutoLockTimeout timeout) async {
    try {
      await _storage.write(_timeoutKey, timeout.name);
    } catch (_) {}
  }

  void lock() {
    _isLocked = true;
  }

  void unlock() {
    _isLocked = false;
    _failedAttempts = 0;
    _lockoutUntil = null;
  }

  void onAppBackgrounded() {
    _backgroundedAt = DateTime.now();
  }

  Future<bool> shouldLockOnResume() async {
    final hasPin = await isPinConfigured();
    if (!hasPin) {
      _isLocked = false;
      return false;
    }

    if (_isLocked) return true;

    final timeout = await getTimeout();
    if (timeout == AutoLockTimeout.never) {
      return false;
    }

    if (timeout == AutoLockTimeout.immediate) {
      _isLocked = true;
      return true;
    }

    if (_backgroundedAt != null) {
      final elapsed = DateTime.now().difference(_backgroundedAt!);
      final duration = timeout.duration;
      if (duration != null && elapsed >= duration) {
        _isLocked = true;
        return true;
      }
    }

    return false;
  }

  List<int> _generateSalt([int length = 16]) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  Future<List<int>> _hashPin(String pin, List<int> salt) async {
    return _hashPinWithKdf(_pbkdf2, pin, salt);
  }

  Future<List<int>> _hashPinWithKdf(
    Pbkdf2 kdf,
    String pin,
    List<int> salt,
  ) async {
    final secretKey = SecretKey(utf8.encode(pin));
    final derived = await kdf.deriveKey(secretKey: secretKey, nonce: salt);
    return derived.extractBytes();
  }

  bool _constantTimeCompare(List<int> a, List<int> b) {
    var result = a.length ^ b.length;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ (i < b.length ? b[i] : 0);
    }
    return result == 0;
  }
}
