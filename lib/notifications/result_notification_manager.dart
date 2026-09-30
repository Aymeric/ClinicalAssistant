import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/health_record.dart';
import 'measurement_signal_analyzer.dart';
import 'local_notification_dispatcher.dart';
import 'result_notification_preferences.dart';

abstract interface class ResultNotificationPreferenceStore {
  Future<ResultNotificationPreferences> load();

  Future<void> save(ResultNotificationPreferences preferences);
}

class SecureResultNotificationPreferenceStore
    implements ResultNotificationPreferenceStore {
  SecureResultNotificationPreferenceStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _preferencesKey = 'result_notification_preferences_v1';
  final FlutterSecureStorage _storage;

  @override
  Future<ResultNotificationPreferences> load() async {
    final saved = await _storage.read(key: _preferencesKey);
    if (saved == null) return const ResultNotificationPreferences();
    return ResultNotificationPreferences.fromJson(saved);
  }

  @override
  Future<void> save(ResultNotificationPreferences preferences) =>
      _storage.write(key: _preferencesKey, value: preferences.toJson());
}

abstract interface class ResultNotificationManager {
  Future<ResultNotificationPreferences> loadPreferences();

  Future<void> savePreferences(ResultNotificationPreferences preferences);

  Future<bool> requestPermission();

  Future<void> notifyForImport({
    required List<HealthRecord> newlyImported,
    required List<HealthRecord> allRecords,
  });
}

class LocalResultNotificationManager implements ResultNotificationManager {
  LocalResultNotificationManager({
    LocalNotificationDispatcher? dispatcher,
    ResultNotificationPreferenceStore? preferenceStore,
    this.onNotificationTap,
  })  : _dispatcher = dispatcher ?? FlutterLocalNotificationDispatcher(),
        _preferenceStore =
            preferenceStore ?? SecureResultNotificationPreferenceStore();

  static const _newResultsNotificationId = 1;
  static const _trendNotificationId = 2;
  static const _patternNotificationId = 3;

  final LocalNotificationDispatcher _dispatcher;
  final ResultNotificationPreferenceStore _preferenceStore;
  final VoidCallback? onNotificationTap;
  final _analyzer = const MeasurementSignalAnalyzer();

  @override
  Future<ResultNotificationPreferences> loadPreferences() async {
    final preferences = await _preferenceStore.load();
    if (preferences.enabled) {
      await _dispatcher.initialize(onNotificationTap: onNotificationTap);
    }
    return preferences;
  }

  @override
  Future<void> savePreferences(ResultNotificationPreferences preferences) =>
      _preferenceStore.save(preferences);

  @override
  Future<bool> requestPermission() async {
    await _dispatcher.initialize(onNotificationTap: onNotificationTap);
    return _dispatcher.requestPermission();
  }

  @override
  Future<void> notifyForImport({
    required List<HealthRecord> newlyImported,
    required List<HealthRecord> allRecords,
  }) async {
    if (newlyImported.isEmpty) return;
    final preferences = await loadPreferences();
    if (!preferences.enabled) return;

    final signals = _analyzer.analyzeImport(
      newlyImported: newlyImported,
      allRecords: allRecords,
      trendThresholdPercent: preferences.trendThresholdPercent,
    );
    if (preferences.newLabResults || preferences.newMeasurements) {
      final newRecordCount =
          (preferences.newLabResults ? signals.newLabResults : 0) +
              (preferences.newMeasurements ? signals.newMeasurements : 0);
      final parts = <String>[
        if (preferences.newLabResults && signals.newLabResults > 0)
          '${signals.newLabResults} new lab ${_plural(signals.newLabResults, 'result')}',
        if (preferences.newMeasurements && signals.newMeasurements > 0)
          '${signals.newMeasurements} new ${_plural(signals.newMeasurements, 'health record')}',
      ];
      if (parts.isNotEmpty) {
        await _show(
          id: _newResultsNotificationId,
          title: 'New health records',
          body:
              '${parts.join(' and ')} ${newRecordCount == 1 ? 'is' : 'are'} ready to review.',
        );
      }
    }

    if (preferences.trends && signals.trendCount > 0) {
      await _show(
        id: _trendNotificationId,
        title: 'Measurement trend',
        body:
            '${signals.trendCount} ${_plural(signals.trendCount, 'measurement')} changed by at least ${preferences.trendThresholdPercent}% between readings.',
      );
    }

    if (preferences.patterns && signals.patternCount > 0) {
      await _show(
        id: _patternNotificationId,
        title: 'Repeated measurement pattern',
        body:
            '${signals.patternCount} ${_plural(signals.patternCount, 'measurement')} had three consecutive readings moving in one direction.',
      );
    }
  }

  Future<void> _initialize() async {
    await _dispatcher.initialize(onNotificationTap: onNotificationTap);
  }

  Future<void> _show({
    required int id,
    required String title,
    required String body,
  }) async {
    await _initialize();
    await _dispatcher.show(title: title, body: body, id: id);
  }
}

String _plural(int count, String singular) =>
    count == 1 ? singular : '${singular}s';
