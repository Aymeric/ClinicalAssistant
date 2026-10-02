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
    directory = await Directory.systemTemp.createTemp('vault-recovery-test-');
    secureStorage = _MemorySecureStorage();
    store = EncryptedRecordStore(
      secureStorage: secureStorage,
      directory: directory,
    );
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('recovers from .tmp file if primary .enc file is corrupt', () async {
    final record = HealthRecord(
      id: 'rec:1',
      name: 'Hemoglobin A1c',
      value: '5.6',
      unit: '%',
      recordedAt: DateTime.utc(2026, 9, 20),
      category: RecordCategory.lab,
      source: 'Lab Corp',
    );

    // Save normally first
    await store.save([record]);

    final primaryFile = File('${directory.path}/records.enc');
    final tmpFile = File('${directory.path}/records.enc.tmp');

    // Simulate saving a new version to .tmp
    final updatedRecord = HealthRecord(
      id: 'rec:2',
      name: 'Hemoglobin A1c',
      value: '5.8',
      unit: '%',
      recordedAt: DateTime.utc(2026, 9, 25),
      category: RecordCategory.lab,
      source: 'Lab Corp',
    );

    // Save valid updated content into .tmp manually by saving to another store with same key
    final helperStore = EncryptedRecordStore(
      secureStorage: secureStorage,
      directory: directory,
    );
    await helperStore.save([updatedRecord]);
    // Copy the valid file to .tmp
    await primaryFile.copy(tmpFile.path);

    // Corrupt the primary file (e.g. power outage mid-write)
    await primaryFile.writeAsString('{"cipherText":"corrupt-half-writ');

    // Load should seamlessly recover from .tmp
    final recovered = await store.load();
    expect(recovered.length, 1);
    expect(recovered.first.id, 'rec:2');
    expect(recovered.first.value, '5.8');

    // Primary file should now be restored
    expect(await primaryFile.exists(), isTrue);
    expect(await store.verifyIntegrity(), isTrue);
  });

  test(
    'recovers from .tmp file if primary file was removed before rename',
    () async {
      final record = HealthRecord(
        id: 'rec:3',
        name: 'Serum Glucose',
        value: '95',
        unit: 'mg/dL',
        recordedAt: DateTime.utc(2026, 9, 22),
        category: RecordCategory.lab,
        source: 'Hospital Lab',
      );

      await store.save([record]);

      final primaryFile = File('${directory.path}/records.enc');
      final tmpFile = File('${directory.path}/records.enc.tmp');

      // Move primary file to .tmp simulating mid-rename failure
      await primaryFile.rename(tmpFile.path);
      expect(await primaryFile.exists(), isFalse);
      expect(await tmpFile.exists(), isTrue);

      // Load should recover and recreate primary file
      final recovered = await store.load();
      expect(recovered.length, 1);
      expect(recovered.first.id, 'rec:3');
      expect(await primaryFile.exists(), isTrue);
    },
  );

  test(
    'verifyIntegrity reports true for valid vault and false for missing key',
    () async {
      expect(await store.verifyIntegrity(), isTrue);

      await store.save([
        HealthRecord(
          id: 'rec:4',
          name: 'Heart Rate',
          value: '72',
          unit: 'bpm',
          recordedAt: DateTime.utc(2026, 9, 24),
          category: RecordCategory.vital,
          source: 'Watch',
        ),
      ]);
      expect(await store.verifyIntegrity(), isTrue);

      // Remove key
      secureStorage.values.clear();
      expect(await store.verifyIntegrity(), isFalse);
    },
  );
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
  }) async => values[key];

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
