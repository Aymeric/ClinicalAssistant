import 'package:clinical_assistant/models/health_record.dart';
import 'package:clinical_assistant/notifications/local_notification_dispatcher.dart';
import 'package:clinical_assistant/notifications/result_notification_manager.dart';
import 'package:clinical_assistant/notifications/result_notification_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sends private import, trend, and pattern summaries once', () async {
    final preferences = _MemoryPreferenceStore();
    final dispatcher = _FakeNotificationDispatcher();
    final manager = LocalResultNotificationManager(
      dispatcher: dispatcher,
      preferenceStore: preferences,
    );
    await manager.savePreferences(
      const ResultNotificationPreferences(enabled: true),
    );
    final records = [
      _reading('first', '100', DateTime.utc(2026, 1, 1)),
      _reading('second', '110', DateTime.utc(2026, 1, 2)),
      _reading('latest', '121', DateTime.utc(2026, 1, 3)),
    ];

    await manager.notifyForImport(
      newlyImported: [records.last],
      allRecords: records,
    );

    expect(dispatcher.notifications, hasLength(3));
    expect(dispatcher.notifications.map((notification) => notification.title), [
      'New health records',
      'Measurement trend',
      'Repeated measurement pattern',
    ]);
    expect(
      dispatcher.notifications[0].body,
      '1 new health record is ready to review.',
    );
    expect(
      dispatcher.notifications[1].body,
      '1 measurement changed by at least 10% between readings.',
    );
    expect(
      dispatcher.notifications[2].body,
      '1 measurement had three consecutive readings moving in one direction.',
    );
    for (final notification in dispatcher.notifications) {
      expect(notification.body, isNot(contains('Heart rate')));
      expect(notification.body, isNot(contains('121')));
    }

    await manager.notifyForImport(newlyImported: const [], allRecords: records);
    expect(dispatcher.notifications, hasLength(3));
  });

  test(
    'respects disabled signal types and disabled overall preference',
    () async {
      final preferences = _MemoryPreferenceStore();
      final dispatcher = _FakeNotificationDispatcher();
      final manager = LocalResultNotificationManager(
        dispatcher: dispatcher,
        preferenceStore: preferences,
      );
      final records = [
        _reading('first', '100', DateTime.utc(2026, 1, 1)),
        _reading('second', '110', DateTime.utc(2026, 1, 2)),
        _reading('latest', '121', DateTime.utc(2026, 1, 3)),
      ];

      await manager.notifyForImport(
        newlyImported: [records.last],
        allRecords: records,
      );
      expect(dispatcher.notifications, isEmpty);

      await manager.savePreferences(
        const ResultNotificationPreferences(
          enabled: true,
          newMeasurements: false,
          trends: false,
          patterns: true,
        ),
      );
      await manager.notifyForImport(
        newlyImported: [records.last],
        allRecords: records,
      );

      expect(dispatcher.notifications, hasLength(1));
      expect(
        dispatcher.notifications.single.title,
        'Repeated measurement pattern',
      );
    },
  );
}

HealthRecord _reading(String id, String value, DateTime recordedAt) {
  return HealthRecord(
    id: id,
    name: 'Heart rate',
    value: value,
    unit: 'bpm',
    recordedAt: recordedAt,
    category: RecordCategory.vital,
    source: 'Health Connect',
  );
}

class _MemoryPreferenceStore implements ResultNotificationPreferenceStore {
  ResultNotificationPreferences preferences =
      const ResultNotificationPreferences();

  @override
  Future<ResultNotificationPreferences> load() async => preferences;

  @override
  Future<void> save(ResultNotificationPreferences preferences) async {
    this.preferences = preferences;
  }
}

class _FakeNotificationDispatcher implements LocalNotificationDispatcher {
  final notifications = <_ShownNotification>[];
  var initialized = false;
  VoidCallback? onNotificationTap;

  @override
  Future<void> initialize({required VoidCallback? onNotificationTap}) async {
    initialized = true;
    this.onNotificationTap = onNotificationTap;
  }

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    notifications.add(_ShownNotification(id, title, body));
  }
}

class _ShownNotification {
  const _ShownNotification(this.id, this.title, this.body);

  final int id;
  final String title;
  final String body;
}
