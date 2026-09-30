import 'dart:io';

import 'package:clinical_assistant/data/encrypted_record_store.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late _MemorySecureStorage secureStorage;
  late EncryptedRecordStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('clinical-vault-test-');
    secureStorage = _MemorySecureStorage();
    store = EncryptedRecordStore(
      secureStorage: secureStorage,
      directory: directory,
    );
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test(
    'encrypts records at rest and restores them from the secure key',
    () async {
      final record = HealthRecord(
        id: 'fhir:glucose-1',
        name: 'Glucose',
        value: '96',
        unit: 'mg/dL',
        recordedAt: DateTime.utc(2026, 9, 20),
        category: RecordCategory.lab,
        source: 'portal.example',
      );

      await store.save([record]);

      final file = File('${directory.path}/records.enc');
      final ciphertext = await file.readAsString();
      expect(ciphertext, isNot(contains('Glucose')));
      expect(ciphertext, isNot(contains('96')));
      expect((await store.load()).single.toJson(), record.toJson());
    },
  );

  test(
    'does not overwrite an existing vault if the secure key is missing',
    () async {
      await store.save([
        HealthRecord(
          id: 'health:source:1',
          name: 'Heart rate',
          value: '72',
          unit: 'bpm',
          recordedAt: DateTime.utc(2026, 9, 20),
          category: RecordCategory.vital,
          source: 'Apple Health',
        ),
      ]);
      final file = File('${directory.path}/records.enc');
      final originalContent = await file.readAsString();
      secureStorage.values.clear();

      await expectLater(store.load(), throwsA(isA<StateError>()));
      await expectLater(store.save(const []), throwsA(isA<StateError>()));
      expect(await file.readAsString(), originalContent);
    },
  );

  test('clears encrypted records and their key', () async {
    await store.save(const []);

    await store.clear();

    expect(await File('${directory.path}/records.enc').exists(), isFalse);
    expect(secureStorage.values, isEmpty);
  });
}

class _MemorySecureStorage extends FlutterSecureStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}
