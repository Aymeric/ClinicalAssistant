import 'package:clinical_assistant/notifications/local_notification_dispatcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'initializes successfully even when plugin returns false (iOS deferred permissions)',
      () async {
    final fakePlugin = _FakeFlutterLocalNotificationsPlugin(
      initializeResult: false,
    );
    final dispatcher = FlutterLocalNotificationDispatcher(plugin: fakePlugin);

    var tapped = false;
    await expectLater(
      dispatcher.initialize(onNotificationTap: () => tapped = true),
      completes,
    );

    expect(fakePlugin.initializeCount, 1);
    expect(tapped, isFalse);
  });

  test('does not re-initialize if already initialized', () async {
    final fakePlugin = _FakeFlutterLocalNotificationsPlugin(
      initializeResult: true,
    );
    final dispatcher = FlutterLocalNotificationDispatcher(plugin: fakePlugin);

    await dispatcher.initialize(onNotificationTap: null);
    await dispatcher.initialize(onNotificationTap: null);

    expect(fakePlugin.initializeCount, 1);
  });

  test('handles app launch from notification', () async {
    var tapped = false;
    final fakePlugin = _FakeFlutterLocalNotificationsPlugin(
      initializeResult: false,
      launchDetails: const NotificationAppLaunchDetails(true),
    );
    final dispatcher = FlutterLocalNotificationDispatcher(plugin: fakePlugin);

    await dispatcher.initialize(onNotificationTap: () => tapped = true);

    expect(tapped, isTrue);
  });
}

class _FakeFlutterLocalNotificationsPlugin
    implements FlutterLocalNotificationsPlugin {
  _FakeFlutterLocalNotificationsPlugin({
    this.initializeResult = true,
    this.launchDetails,
  });

  final bool? initializeResult;
  final NotificationAppLaunchDetails? launchDetails;
  int initializeCount = 0;

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
        onDidReceiveBackgroundNotificationResponse,
  }) async {
    initializeCount++;
    return initializeResult;
  }

  @override
  Future<NotificationAppLaunchDetails?>
      getNotificationAppLaunchDetails() async {
    return launchDetails;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
