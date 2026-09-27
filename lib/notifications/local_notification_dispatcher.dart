import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract interface class LocalNotificationDispatcher {
  Future<void> initialize({required VoidCallback? onNotificationTap});

  Future<bool> requestPermission();

  Future<void> show({
    required int id,
    required String title,
    required String body,
  });
}

class FlutterLocalNotificationDispatcher
    implements LocalNotificationDispatcher {
  FlutterLocalNotificationDispatcher({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  var _initialized = false;
  var _launchDetailsChecked = false;
  Future<void>? _initializing;

  @override
  Future<void> initialize({required VoidCallback? onNotificationTap}) async {
    if (_initialized && _launchDetailsChecked) return;
    final initializing = _initializing ??= _initialize(
      onNotificationTap: onNotificationTap,
    );
    try {
      await initializing;
    } catch (_) {
      if (identical(_initializing, initializing)) _initializing = null;
      rethrow;
    }
  }

  Future<void> _initialize({required VoidCallback? onNotificationTap}) async {
    if (!_initialized) {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (_) => onNotificationTap?.call(),
      );
      _initialized = true;
    }
    if (!_launchDetailsChecked) {
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      _launchDetailsChecked = true;
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        onNotificationTap?.call();
      }
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return result ?? false;
    }
    if (Platform.isIOS) {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, sound: true);
      return result ?? false;
    }
    return false;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      payload: 'records',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'health_record_updates',
          'Health record updates',
          channelDescription: 'Private alerts about newly imported records and measurement patterns.',
          icon: 'ic_notification',
          visibility: NotificationVisibility.private,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      ),
    );
  }
}
