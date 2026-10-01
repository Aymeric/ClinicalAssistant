import 'dart:convert';

import 'package:clinical_assistant/data/vault_backup_service.dart';
import 'package:clinical_assistant/models/health_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VaultBackupService', () {
    late VaultBackupService service;

    setUp(() {
      service = VaultBackupService();
    });

    final sampleRecords = [
      HealthRecord(
        id: 'vital:bp:sys',
        name: 'Systolic blood pressure',
        value: '122',
        unit: 'mmHg',
        recordedAt: DateTime.utc(2025, 6, 1, 9, 30),
        category: RecordCategory.vital,
        source: 'Manual Entry',
        notes: 'Morning measurement before coffee',
      ),
      HealthRecord(
        id: 'lab:glucose',
        name: 'Fasting Blood Glucose',
        value: '95',
        unit: 'mg/dL',
        recordedAt: DateTime.utc(2025, 6, 2, 8, 0),
        category: RecordCategory.lab,
        source: 'Hospital Lab',
        referenceRange: '70 - 99 mg/dL',
        status: 'final',
        code: '1558-6',
        sourceId: 'obs-glucose-99',
      ),
    ];

    test(
      'exports encrypted backup and restores with exact data preservation',
      () async {
        const password = 'my-secret-vault-passphrase';
        final backupJson = await service.exportEncryptedBackup(
          sampleRecords,
          password,
        );

        expect(backupJson, isNotEmpty);
        final decodedEnvelope = jsonDecode(backupJson) as Map<String, dynamic>;
        expect(decodedEnvelope['format'], 'clinical_assistant_vault_backup_v1');
        expect(decodedEnvelope['recordCount'], 2);
        expect(decodedEnvelope['kdf']['algorithm'], 'PBKDF2-HMAC-SHA256');
        expect(decodedEnvelope['cipher']['algorithm'], 'AES-256-GCM');
        expect(decodedEnvelope['cipher']['ciphertext'], isNotEmpty);
        expect(decodedEnvelope['cipher']['nonce'], isNotEmpty);
        expect(decodedEnvelope['cipher']['mac'], isNotEmpty);

        // Plaintext record content should NOT appear unencrypted in backupJson
        expect(
          backupJson.contains('Morning measurement before coffee'),
          isFalse,
        );
        expect(backupJson.contains('Systolic blood pressure'), isFalse);

        final restored = await service.restoreEncryptedBackup(
          backupJson,
          password,
        );
        expect(restored.length, 2);
        expect(restored[0].id, 'vital:bp:sys');
        expect(restored[0].name, 'Systolic blood pressure');
        expect(restored[0].value, '122');
        expect(restored[0].isManual, isTrue);
        expect(restored[0].notes, 'Morning measurement before coffee');

        expect(restored[1].id, 'lab:glucose');
        expect(restored[1].referenceRange, '70 - 99 mg/dL');
        expect(restored[1].status, 'final');
        expect(restored[1].code, '1558-6');
      },
    );

    test('fails decryption when given incorrect passphrase', () async {
      const correctPass = 'correct-vault-password';
      const wrongPass = 'wrong-vault-password';

      final backupJson = await service.exportEncryptedBackup(
        sampleRecords,
        correctPass,
      );

      expect(
        () => service.restoreEncryptedBackup(backupJson, wrongPass),
        throwsA(isA<VaultBackupAuthException>()),
      );
    });

    test('fails restore on corrupted ciphertext', () async {
      const password = 'my-vault-password';
      final backupJson = await service.exportEncryptedBackup(
        sampleRecords,
        password,
      );
      final decoded = jsonDecode(backupJson) as Map<String, dynamic>;

      // Corrupt ciphertext
      final rawCipher = base64Decode(decoded['cipher']['ciphertext'] as String);
      rawCipher[0] = rawCipher[0] ^ 0xFF;
      decoded['cipher']['ciphertext'] = base64Encode(rawCipher);

      final corruptedJson = jsonEncode(decoded);
      expect(
        () => service.restoreEncryptedBackup(corruptedJson, password),
        throwsA(isA<VaultBackupAuthException>()),
      );
    });

    test('validates minimum passphrase length on export', () async {
      expect(
        () => service.exportEncryptedBackup(sampleRecords, '12345'),
        throwsArgumentError,
      );
    });

    test('rejects empty passphrase on restore', () async {
      expect(
        () => service.restoreEncryptedBackup('{}', '   '),
        throwsArgumentError,
      );
    });

    test('rejects insecure or excessive PBKDF2 iteration counts', () async {
      const password = 'my-vault-password';
      final backupJson = await service.exportEncryptedBackup(
        sampleRecords,
        password,
      );

      final decodedLow = jsonDecode(backupJson) as Map<String, dynamic>;
      (decodedLow['kdf'] as Map<String, dynamic>)['iterations'] = 1000;
      expect(
        () => service.restoreEncryptedBackup(jsonEncode(decodedLow), password),
        throwsFormatException,
      );

      final decodedHigh = jsonDecode(backupJson) as Map<String, dynamic>;
      (decodedHigh['kdf'] as Map<String, dynamic>)['iterations'] = 2000000;
      expect(
        () => service.restoreEncryptedBackup(jsonEncode(decodedHigh), password),
        throwsFormatException,
      );
    });

    test('rejects invalid JSON or incompatible format', () async {
      const password = 'password123';
      expect(
        () => service.restoreEncryptedBackup('not a json string', password),
        throwsFormatException,
      );

      final invalidFormat = jsonEncode({
        'format': 'unknown_format_v99',
        'kdf': {},
        'cipher': {},
      });
      expect(
        () => service.restoreEncryptedBackup(invalidFormat, password),
        throwsFormatException,
      );
    });
  });
}
