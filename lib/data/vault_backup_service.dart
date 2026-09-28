import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../models/health_record.dart';

class VaultBackupService {
  VaultBackupService({
    AesGcm? cipher,
    Pbkdf2? kdf,
  })  : _cipher = cipher ?? AesGcm.with256bits(),
        _kdf = kdf ??
            Pbkdf2(
              macAlgorithm: Hmac.sha256(),
              iterations: 100000,
              bits: 256,
            );

  static const String currentFormat = 'clinical_assistant_vault_backup_v1';
  static const int saltLength = 16;

  final AesGcm _cipher;
  final Pbkdf2 _kdf;

  Uint8List _generateRandomSalt() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(saltLength, (_) => random.nextInt(256)),
    );
  }

  Future<String> exportEncryptedBackup(
    List<HealthRecord> records,
    String passphrase,
  ) async {
    if (passphrase.trim().length < 6) {
      throw ArgumentError('Passphrase must be at least 6 characters.');
    }

    final salt = _generateRandomSalt();
    final secretKey = await _kdf.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );

    final payloadJson = jsonEncode(
      records.map((r) => r.toJson()).toList(),
    );
    final cleartextBytes = utf8.encode(payloadJson);

    final secretBox = await _cipher.encrypt(
      cleartextBytes,
      secretKey: secretKey,
    );

    final envelope = <String, dynamic>{
      'format': currentFormat,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'recordCount': records.length,
      'kdf': {
        'algorithm': 'PBKDF2-HMAC-SHA256',
        'iterations': 100000,
        'salt': base64Encode(salt),
      },
      'cipher': {
        'algorithm': 'AES-256-GCM',
        'nonce': base64Encode(secretBox.nonce),
        'ciphertext': base64Encode(secretBox.cipherText),
        'mac': base64Encode(secretBox.mac.bytes),
      },
    };

    return const JsonEncoder.withIndent('  ').convert(envelope);
  }

  Future<List<HealthRecord>> restoreEncryptedBackup(
    String backupJson,
    String passphrase,
  ) async {
    if (passphrase.trim().isEmpty) {
      throw ArgumentError('Passphrase cannot be empty.');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(backupJson);
    } catch (_) {
      throw const FormatException('Backup file is not valid JSON.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid vault backup payload structure.');
    }

    final format = decoded['format'];
    if (format != currentFormat) {
      throw FormatException(
        'Unsupported vault backup format: $format. Expected $currentFormat.',
      );
    }

    final kdfMap = decoded['kdf'];
    final cipherMap = decoded['cipher'];
    if (kdfMap is! Map || cipherMap is! Map) {
      throw const FormatException('Missing cryptographic parameters in backup.');
    }

    final saltB64 = kdfMap['salt'] as String?;
    final iterations = (kdfMap['iterations'] as num?)?.toInt() ?? 100000;
    if (saltB64 == null) {
      throw const FormatException('Missing KDF salt in backup.');
    }
    final salt = base64Decode(saltB64);

    final nonceB64 = cipherMap['nonce'] as String?;
    final cipherB64 = cipherMap['ciphertext'] as String?;
    final macB64 = cipherMap['mac'] as String?;

    if (nonceB64 == null || cipherB64 == null || macB64 == null) {
      throw const FormatException('Missing ciphertext, nonce, or mac in backup.');
    }

    final kdf = iterations == 100000
        ? _kdf
        : Pbkdf2(
            macAlgorithm: Hmac.sha256(),
            iterations: iterations,
            bits: 256,
          );

    final secretKey = await kdf.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );

    final secretBox = SecretBox(
      base64Decode(cipherB64),
      nonce: base64Decode(nonceB64),
      mac: Mac(base64Decode(macB64)),
    );

    List<int> cleartext;
    try {
      cleartext = await _cipher.decrypt(
        secretBox,
        secretKey: secretKey,
      );
    } on SecretBoxAuthenticationError {
      throw const VaultBackupAuthException(
        'Incorrect passphrase or corrupted backup file.',
      );
    } catch (e) {
      throw VaultBackupAuthException(
        'Decryption failed: could not authenticate backup. $e',
      );
    }

    final recordsJson = jsonDecode(utf8.decode(cleartext));
    if (recordsJson is! List) {
      throw const FormatException('Decrypted content is not a record list.');
    }

    return recordsJson
        .map((r) => HealthRecord.fromJson(Map<String, Object?>.from(r as Map)))
        .toList();
  }
}

class VaultBackupAuthException implements Exception {
  const VaultBackupAuthException(this.message);
  final String message;

  @override
  String toString() => message;
}
