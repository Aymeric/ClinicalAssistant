import 'package:clinical_assistant/data/pinned_metrics_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _MemorySecureStorage secureStorage;
  late PinnedMetricsPreferences preferences;

  setUp(() {
    secureStorage = _MemorySecureStorage();
    preferences = PinnedMetricsPreferences(secureStorage: secureStorage);
  });

  test('defaults to empty set of pinned metrics', () async {
    expect(await preferences.getPinnedSeries(), isEmpty);
  });

  test('toggles pinning of series IDs', () async {
    expect(await preferences.isPinned('vital:Blood Pressure'), isFalse);

    final pinned = await preferences.togglePin('vital:Blood Pressure');
    expect(pinned, isTrue);
    expect(await preferences.isPinned('vital:Blood Pressure'), isTrue);
    expect(await preferences.getPinnedSeries(), {'vital:Blood Pressure'});

    final unpinned = await preferences.togglePin('vital:Blood Pressure');
    expect(unpinned, isFalse);
    expect(await preferences.isPinned('vital:Blood Pressure'), isFalse);
    expect(await preferences.getPinnedSeries(), isEmpty);
  });

  test('sets and clears multiple pinned metrics', () async {
    await preferences.setPinnedSeries({'vital:Blood Pressure', 'lab:Glucose'});
    expect(await preferences.getPinnedSeries(), {
      'vital:Blood Pressure',
      'lab:Glucose',
    });

    await preferences.clear();
    expect(await preferences.getPinnedSeries(), isEmpty);
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
