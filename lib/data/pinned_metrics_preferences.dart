import 'dart:convert';

import 'package:clinical_assistant/sync/foreground_sync_state.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinnedMetricsPreferences {
  PinnedMetricsPreferences({
    SyncValueStore? storage,
    FlutterSecureStorage? secureStorage,
  }) : _storage =
           storage ??
           SecureSyncValueStore(
             storage: secureStorage ?? const FlutterSecureStorage(),
           );

  static const _keyName = 'clinical_assistant_pinned_metrics_v1';
  final SyncValueStore _storage;

  Future<Set<String>> getPinnedSeries() async {
    final raw = await _storage.read(_keyName);
    if (raw == null || raw.isEmpty) return const {};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => e.toString()).toSet();
    } catch (_) {
      return const {};
    }
  }

  Future<void> setPinnedSeries(Set<String> seriesIds) async {
    await _storage.write(_keyName, jsonEncode(seriesIds.toList()));
  }

  Future<bool> isPinned(String seriesId) async {
    final pinned = await getPinnedSeries();
    return pinned.contains(seriesId);
  }

  Future<bool> togglePin(String seriesId) async {
    final pinned = (await getPinnedSeries()).toSet();
    final wasPinned = pinned.contains(seriesId);
    if (wasPinned) {
      pinned.remove(seriesId);
    } else {
      pinned.add(seriesId);
    }
    await setPinnedSeries(pinned);
    return !wasPinned;
  }

  Future<void> clear() async {
    await _storage.delete(_keyName);
  }
}
