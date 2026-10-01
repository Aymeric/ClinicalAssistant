import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'local_vault_directory.dart';
import '../models/health_record.dart';

class EncryptedRecordStore {
  EncryptedRecordStore({FlutterSecureStorage? secureStorage, Directory? directory})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
      _directory = directory,
      _algorithm = AesGcm.with256bits();

  static const _keyName = 'clinical_assistant_vault_key_v1';
  static const _fileName = 'records.enc';

  final FlutterSecureStorage _secureStorage;
  final Directory? _directory;
  final AesGcm _algorithm;

  Future<List<HealthRecord>> load() async {
    final file = await _file();
    if (!await file.exists()) return const [];

    final encodedKey = await _secureStorage.read(key: _keyName);
    if (encodedKey == null) {
      throw StateError(
        'The secure key for this health-data vault is missing. The encrypted records were left untouched.',
      );
    }
    final envelope =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
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
    await temporaryFile.rename(file.path);
  }

  Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
    await _secureStorage.delete(key: _keyName);
  }

  Future<File> _file() async {
    final appDirectory = _directory ?? await LocalVaultDirectory.resolve();
    await appDirectory.create(recursive: true);
    return File('${appDirectory.path}/$_fileName');
  }
}
