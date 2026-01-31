import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:evmrider/models/event.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();

  NotificationService._();

  final StreamController<void> _tapController =
      StreamController<void>.broadcast();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  int _nextId = 1;

  static const String _androidChannelId = 'evm_events';
  static const String _androidChannelName = 'EVM Events';
  static const String _androidChannelDescription =
      'Notifications when subscribed contract events fire.';

  Stream<void> get onNotificationTap => _tapController.stream;

  Future<void> ensureInitialized() async {
    if (_initialized || kIsWeb) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    const linux = LinuxInitializationSettings(defaultActionName: 'Open');
    const windows = WindowsInitializationSettings(
      appName: 'EVM Rider',
      appUserModelId: 'com.peerchemist.evmrider',
      guid: '6a3f00db-776f-4fc0-9a73-7c1ae4f0c8c7',
    );

    const initSettings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
      linux: linux,
      windows: windows,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImpl != null) {
      const channel = AndroidNotificationChannel(
        _androidChannelId,
        _androidChannelName,
        description: _androidChannelDescription,
        importance: Importance.defaultImportance,
      );
      await androidImpl.createNotificationChannel(channel);
    }

    _initialized = true;
  }

  Future<void> requestPermissionsIfNeeded() async {
    if (kIsWeb) return;
    await ensureInitialized();

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
    }

    final iosImpl = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (iosImpl != null) {
      await iosImpl.requestPermissions(alert: true, badge: true, sound: true);
    }

    final macImpl = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    if (macImpl != null) {
      await macImpl.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  Future<void> notifyEvent(Event event, {bool silent = false}) async {
    if (kIsWeb) return;
    await ensureInitialized();

    final id = _nextId++;
    final title = event.eventName.isEmpty ? 'EVM Event' : event.eventName;
    final body = 'Block ${event.blockNumber} • ${event.transactionHash}';

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: _androidChannelDescription,
          importance:
              silent ? Importance.low : Importance.defaultImportance,
          priority: silent ? Priority.low : Priority.defaultPriority,
          playSound: !silent,
          enableVibration: !silent,
        ),
        iOS: DarwinNotificationDetails(presentSound: !silent),
        macOS: DarwinNotificationDetails(presentSound: !silent),
        linux: const LinuxNotificationDetails(),
        windows: const WindowsNotificationDetails(),
      ),
    );
  }

  void _handleNotificationResponse(NotificationResponse response) {
    _tapController.add(null);
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // No-op: the UI will refresh on resume. This keeps the callback registered.
}
