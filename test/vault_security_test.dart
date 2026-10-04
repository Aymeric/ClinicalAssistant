import 'package:clinical_assistant/data/vault_security_service.dart';
import 'package:clinical_assistant/sync/foreground_sync_state.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemorySyncValueStore implements SyncValueStore {
  final _values = <String, String>{};
  @override
  Future<String?> read(String key) async => _values[key];
  @override
  Future<void> write(String key, String value) async => _values[key] = value;
  @override
  Future<void> delete(String key) async => _values.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VaultSecurityService', () {
    late _MemorySyncValueStore memoryStore;
    late VaultSecurityService service;

    setUp(() {
      memoryStore = _MemorySyncValueStore();
      service = VaultSecurityService(storage: memoryStore);
    });

    test('initial state has no PIN configured', () async {
      expect(await service.isPinConfigured(), isFalse);
      expect(service.isLocked, isFalse);
      expect(service.isRateLimited, isFalse);
    });

    test('sets and verifies correct PIN', () async {
      await service.setPin('1234');
      expect(await service.isPinConfigured(), isTrue);

      final isValid = await service.verifyPin('1234');
      expect(isValid, isTrue);

      final isInvalid = await service.verifyPin('9999');
      expect(isInvalid, isFalse);
    });

    test('rejects PINs shorter than 4 digits', () async {
      expect(() => service.setPin('12'), throwsArgumentError);
    });

    test(
      'enforces rate limiting after 5 consecutive failed attempts',
      () async {
        await service.setPin('4321');

        for (var i = 0; i < 4; i++) {
          final result = await service.verifyPin('0000');
          expect(result, isFalse);
          expect(service.isRateLimited, isFalse);
        }

        // 5th failed attempt triggers lockout
        final fifth = await service.verifyPin('0000');
        expect(fifth, isFalse);
        expect(service.isRateLimited, isTrue);
        expect(service.remainingLockoutSeconds, greaterThan(0));

        // Even correct PIN is blocked during rate limit
        final correctDuringLockout = await service.verifyPin('4321');
        expect(correctDuringLockout, isFalse);
      },
    );

    test('changes PIN when old PIN is correct', () async {
      await service.setPin('1111');

      final failedChange = await service.changePin('0000', '2222');
      expect(failedChange, isFalse);
      expect(await service.verifyPin('1111'), isTrue);

      final successfulChange = await service.changePin('1111', '2222');
      expect(successfulChange, isTrue);
      expect(await service.verifyPin('1111'), isFalse);
      expect(await service.verifyPin('2222'), isTrue);
    });

    test('removes PIN and clears stored credentials', () async {
      await service.setPin('5555');
      expect(await service.isPinConfigured(), isTrue);

      final failedRemove = await service.removePin('0000');
      expect(failedRemove, isFalse);
      expect(await service.isPinConfigured(), isTrue);

      final successfulRemove = await service.removePin('5555');
      expect(successfulRemove, isTrue);
      expect(await service.isPinConfigured(), isFalse);
    });

    test(
      'verifies and transparently upgrades legacy 10,000 iteration PIN hashes',
      () async {
        final legacyService = VaultSecurityService(
          storage: memoryStore,
          pbkdf2: Pbkdf2(
            macAlgorithm: Hmac.sha256(),
            iterations: 10000,
            bits: 256,
          ),
        );
        // Simulate existing stored hash created prior to upgrade (with no stored iterations key)
        await legacyService.setPin('8888');
        await memoryStore.delete('vault_pin_iterations_v1');

        // Verify with VaultSecurityService that defaults to 100,000 iterations
        final verified = await service.verifyPin('8888');
        expect(verified, isTrue);

        // Verify iteration key was upgraded in storage
        final iterationsStored = await memoryStore.read(
          'vault_pin_iterations_v1',
        );
        expect(iterationsStored, equals('100000'));
      },
    );

    test('persists and parses auto-lock timeouts', () async {
      expect(await service.getTimeout(), AutoLockTimeout.immediate);

      await service.setTimeout(AutoLockTimeout.fiveMinutes);
      expect(await service.getTimeout(), AutoLockTimeout.fiveMinutes);

      await service.setTimeout(AutoLockTimeout.never);
      expect(await service.getTimeout(), AutoLockTimeout.never);
    });

    test('calculates shouldLockOnResume accurately', () async {
      // Without PIN configured, should never lock
      expect(await service.shouldLockOnResume(), isFalse);

      await service.setPin('7777');
      await service.setTimeout(AutoLockTimeout.immediate);

      // Immediate timeout locks on resume
      expect(await service.shouldLockOnResume(), isTrue);
      expect(service.isLocked, isTrue);

      // Unlocking clears isLocked
      service.unlock();
      expect(service.isLocked, isFalse);

      // Never timeout does not lock on resume
      await service.setTimeout(AutoLockTimeout.never);
      expect(await service.shouldLockOnResume(), isFalse);
    });
  });
}
