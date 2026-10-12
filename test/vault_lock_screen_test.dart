import 'package:clinical_assistant/data/vault_security_service.dart';
import 'package:clinical_assistant/sync/foreground_sync_state.dart';
import 'package:clinical_assistant/ui/security/vault_lock_screen.dart';
import 'package:flutter/material.dart';
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

  testWidgets(
    'VaultLockScreen provides accessible PIN progress and digit button semantics',
    (WidgetTester tester) async {
      final handle = tester.ensureSemantics();
      final service = VaultSecurityService(storage: _MemorySyncValueStore());

      await tester.pumpWidget(
        MaterialApp(
          home: VaultLockScreen(securityService: service, onUnlocked: () {}),
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial live region semantics for PIN progress
      expect(find.bySemanticsLabel('0 of 4 digits entered'), findsOneWidget);

      // Verify keypad digit button semantics
      expect(find.bySemanticsLabel(RegExp(r'Digit 1')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'Digit 2')), findsOneWidget);

      // Tap digits and verify live region progress updates
      await tester.tap(find.byKey(const ValueKey('vault-pin-digit-1')));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('1 of 4 digits entered'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('vault-pin-digit-2')));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('2 of 4 digits entered'), findsOneWidget);

      handle.dispose();
    },
  );
}
