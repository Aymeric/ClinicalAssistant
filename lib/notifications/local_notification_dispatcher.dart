import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationAction {
  const LocalNotificationAction({
    required this.id,
    required this.label,
    this.showsUserInterface = true,
  });

  final String id;
  final String label;
  final bool showsUserInterface;
}

typedef NotificationActionCallback =
    void Function(String? actionId, String? payload);

abstract interface class LocalNotificationDispatcher {
  Future<void> initialize({
    required VoidCallback? onNotificationTap,
    NotificationActionCallback? onNotificationAction,
  });

  Future<bool> requestPermission();

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
    List<LocalNotificationAction> actions = const [],
  });

  Future<void> cancel({required int id});
}

class FlutterLocalNotificationDispatcher
    implements LocalNotificationDispatcher {
  FlutterLocalNotificationDispatcher({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const medicationReminderCategoryId = 'medication_reminder_actions';
  static const actionMarkTaken = 'mark_taken';
  static const actionMarkSkipped = 'mark_skipped';

  final FlutterLocalNotificationsPlugin _plugin;
  var _initialized = false;
  var _launchDetailsChecked = false;
  Future<void>? _initializing;
  VoidCallback? _onNotificationTap;
  NotificationActionCallback? _onNotificationAction;

  @override
  Future<void> initialize({
    required VoidCallback? onNotificationTap,
    NotificationActionCallback? onNotificationAction,
  }) async {
    if (onNotificationTap != null) {
      _onNotificationTap = onNotificationTap;
    }
    if (onNotificationAction != null) {
      _onNotificationAction = onNotificationAction;
    }
    if (_initialized && _launchDetailsChecked) return;
    final initializing = _initializing ??= _initialize();
    try {
      await initializing;
    } catch (_) {
      if (identical(_initializing, initializing)) _initializing = null;
      rethrow;
    }
  }

  void _handleResponse(NotificationResponse response) {
    final actionId = response.actionId;
    final payload = response.payload;
    if (actionId != null && actionId.isNotEmpty) {
      _onNotificationAction?.call(actionId, payload);
      return;
    }
    if (payload != null && payload.startsWith('medication:')) {
      _onNotificationAction?.call(null, payload);
      return;
    }
    _onNotificationTap?.call();
  }

  Future<void> _initialize() async {
    if (!_initialized) {
      await _plugin.initialize(
        settings: InitializationSettings(
          android: const AndroidInitializationSettings('ic_notification'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
            notificationCategories: [
              DarwinNotificationCategory(
                medicationReminderCategoryId,
                actions: [
                  DarwinNotificationAction.plain(
                    actionMarkTaken,
                    'Taken',
                    options: <DarwinNotificationActionOption>{
                      DarwinNotificationActionOption.foreground,
                    },
                  ),
                  DarwinNotificationAction.plain(
                    actionMarkSkipped,
                    'Skipped',
                    options: <DarwinNotificationActionOption>{
                      DarwinNotificationActionOption.foreground,
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        onDidReceiveNotificationResponse: _handleResponse,
      );
      _initialized = true;
    }
    if (!_launchDetailsChecked) {
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      _launchDetailsChecked = true;
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        final response = launchDetails?.notificationResponse;
        if (response != null) {
          _handleResponse(response);
        } else {
          _onNotificationTap?.call();
        }
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
    String? payload,
    List<LocalNotificationAction> actions = const [],
  }) async {
    final androidActions = actions
        .map(
          (a) => AndroidNotificationAction(
            a.id,
            a.label,
            showsUserInterface: a.showsUserInterface,
          ),
        )
        .toList();

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      payload: payload ?? 'records',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'health_record_updates',
          'Health record updates',
          channelDescription:
              'Private alerts about newly imported records and measurement patterns.',
          icon: 'ic_notification',
          visibility: NotificationVisibility.private,
          actions: androidActions.isEmpty ? null : androidActions,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
          categoryIdentifier: actions.isEmpty
              ? null
              : medicationReminderCategoryId,
        ),
      ),
    );
  }

  @override
  Future<void> cancel({required int id}) async {
    await _plugin.cancel(id: id);
  }
}
