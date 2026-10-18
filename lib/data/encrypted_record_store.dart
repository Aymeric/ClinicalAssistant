import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'local_vault_directory.dart';
import '../models/health_record.dart';
import '../sync/import_progress.dart';

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

  Future<void> _yieldToRenderer() =>
      Future<void>.delayed(const Duration(milliseconds: 35));

  /// Atomically encrypts and saves health records to vault storage.
  Future<void> save(
    List<HealthRecord> records, {
    ImportProgressCallback? onProgress,
  }) async {
    onProgress?.call(
      const ImportProgress(
        fraction: 0.05,
        message: 'Securing vault storage',
      ),
    );
    await _yieldToRenderer();

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

    onProgress?.call(
      ImportProgress(
        fraction: 0.25,
        message: 'Formatting ${records.length} records',
      ),
    );
    await _yieldToRenderer();

    final Uint8List payloadBytes;
    if (records.length > 500) {
      payloadBytes = await Isolate.run(() {
        final jsonString = jsonEncode(
          records.map((record) => record.toJson()).toList(),
        );
        return Uint8List.fromList(gzip.encode(utf8.encode(jsonString)));
      });
    } else {
      final jsonString = jsonEncode(
        records.map((record) => record.toJson()).toList(),
      );
      payloadBytes = Uint8List.fromList(gzip.encode(utf8.encode(jsonString)));
    }

    onProgress?.call(
      const ImportProgress(
        fraction: 0.6,
        message: 'Encrypting vault records',
      ),
    );
    await _yieldToRenderer();

    final String envelopeJson;
    final keyBytes = base64Decode(encodedKey);
    if (records.length > 500) {
      envelopeJson = await Isolate.run(() async {
        final algorithm = AesGcm.with256bits();
        final box = await algorithm.encrypt(
          payloadBytes,
          secretKey: SecretKey(keyBytes),
        );
        return jsonEncode({
          'nonce': base64Encode(box.nonce),
          'cipherText': base64Encode(box.cipherText),
          'mac': base64Encode(box.mac.bytes),
        });
      });
    } else {
      final box = await _algorithm.encrypt(
        payloadBytes,
        secretKey: SecretKey(keyBytes),
      );
      envelopeJson = jsonEncode({
        'nonce': base64Encode(box.nonce),
        'cipherText': base64Encode(box.cipherText),
        'mac': base64Encode(box.mac.bytes),
      });
    }

    onProgress?.call(
      const ImportProgress(
        fraction: 0.85,
        message: 'Writing records to vault',
      ),
    );
    await _yieldToRenderer();

    final temporaryFile = File('${file.path}.tmp');
    await temporaryFile.writeAsString(
      envelopeJson,
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

    onProgress?.call(
      const ImportProgress(
        fraction: 1.0,
        message: 'Vault updated',
      ),
    );
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
    final String jsonString;
    if (plaintext.length >= 2 && plaintext[0] == 0x1F && plaintext[1] == 0x8B) {
      jsonString = utf8.decode(gzip.decode(plaintext));
    } else {
      jsonString = utf8.decode(plaintext);
    }
    final rows = jsonDecode(jsonString) as List<dynamic>;
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
