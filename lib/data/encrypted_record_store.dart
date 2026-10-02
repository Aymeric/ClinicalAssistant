import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'local_vault_directory.dart';
import '../models/health_record.dart';

class EncryptedRecordStore {
  EncryptedRecordStore({FlutterSecureStorage? secureStorage, this.directory})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
      _algorithm = AesGcm.with256bits();

  static const _keyName = 'clinical_assistant_vault_key_v1';
  static const _fileName = 'records.enc';

  final FlutterSecureStorage _secureStorage;
  final Directory? directory;
  final AesGcm _algorithm;

  /// Loads and decrypts health records from local vault storage.
  /// If the primary file was corrupted or missing due to a crash during write,
  /// this automatically attempts recovery from the atomic temporary file.
  Future<List<HealthRecord>> load() async {
    final file = await _file();
    final tmpFile = File('${file.path}.tmp');

    final fileExists = await file.exists();
    final tmpExists = await tmpFile.exists();

    if (!fileExists && !tmpExists) return const [];

    final encodedKey = await _secureStorage.read(key: _keyName);
    if (encodedKey == null) {
      throw StateError(
        'The secure key for this health-data vault is missing. The encrypted records were left untouched.',
      );
    }

    if (fileExists) {
      try {
        final records = await _readFromEnvelopeFile(file, encodedKey);
        if (tmpExists) {
          try {
            await tmpFile.delete();
          } catch (_) {}
        }
        return records;
      } catch (error) {
        if (tmpExists) {
          try {
            final recovered = await _readFromEnvelopeFile(tmpFile, encodedKey);
            try {
              await tmpFile.rename(file.path);
            } on FileSystemException {
              await tmpFile.copy(file.path);
              await tmpFile.delete();
            }
            return recovered;
          } catch (_) {}
        }
        rethrow;
      }
    } else if (tmpExists) {
      final recovered = await _readFromEnvelopeFile(tmpFile, encodedKey);
      try {
        await tmpFile.rename(file.path);
      } on FileSystemException {
        await tmpFile.copy(file.path);
        await tmpFile.delete();
      }
      return recovered;
    }

    return const [];
  }

  /// Atomically encrypts and saves health records to vault storage.
  Future<void> save(List<HealthRecord> records) async {
    final file = await _file();
    final hasExistingFile = await file.exists();
    var encodedKey = await _secureStorage.read(key: _keyName);
    if (encodedKey == null) {
      if (hasExistingFile) {
        throw StateError(
          'The secure key for this health-data vault is missing. Refusing to replace the encrypted records.',
        );
      }
      final key = await _algorithm.newSecretKey();
      encodedKey = base64Encode(await key.extractBytes());
      await _secureStorage.write(key: _keyName, value: encodedKey);
    }

    final box = await _algorithm.encrypt(
      utf8.encode(
        jsonEncode(records.map((record) => record.toJson()).toList()),
      ),
      secretKey: SecretKey(base64Decode(encodedKey)),
    );
    final temporaryFile = File('${file.path}.tmp');
    await temporaryFile.writeAsString(
      jsonEncode({
        'nonce': base64Encode(box.nonce),
        'cipherText': base64Encode(box.cipherText),
        'mac': base64Encode(box.mac.bytes),
      }),
      flush: true,
    );
    try {
      await temporaryFile.rename(file.path);
    } on FileSystemException {
      await temporaryFile.copy(file.path);
      try {
        await temporaryFile.delete();
      } catch (_) {}
    }
  }

  /// Verifies that the encrypted vault is present, decryptable, and uncorrupted.
  Future<bool> verifyIntegrity() async {
    try {
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Clears encrypted records, temporary recovery files, and their secure encryption key.
  Future<void> clear() async {
    final file = await _file();
    final tmpFile = File('${file.path}.tmp');
    if (await file.exists()) await file.delete();
    if (await tmpFile.exists()) await tmpFile.delete();
    await _secureStorage.delete(key: _keyName);
  }

  Future<List<HealthRecord>> _readFromEnvelopeFile(
    File targetFile,
    String encodedKey,
  ) async {
    final envelope =
        jsonDecode(await targetFile.readAsString()) as Map<String, dynamic>;
    final box = SecretBox(
      base64Decode(envelope['cipherText']! as String),
      nonce: base64Decode(envelope['nonce']! as String),
      mac: Mac(base64Decode(envelope['mac']! as String)),
    );
    final plaintext = await _algorithm.decrypt(
      box,
      secretKey: SecretKey(base64Decode(encodedKey)),
    );
    final rows = jsonDecode(utf8.decode(plaintext)) as List<dynamic>;
    return rows
        .map(
          (row) => HealthRecord.fromJson(Map<String, Object?>.from(row as Map)),
        )
        .toList();
  }

  Future<File> _file() async {
    final appDirectory = directory ?? await LocalVaultDirectory.resolve();
    await appDirectory.create(recursive: true);
    return File('${appDirectory.path}/$_fileName');
  }
}
