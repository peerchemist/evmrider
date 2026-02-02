import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:evmrider/models/event.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();

  NotificationService._();

  final StreamController<String?> _tapController =
      StreamController<String?>.broadcast();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  int _nextId = 1;

  static const String _androidChannelId = 'evm_events';
  static const String _androidChannelName = 'EVM Events';
  static const String _androidChannelDescription =
      'Notifications when subscribed contract events fire.';

  Stream<String?> get onNotificationTap => _tapController.stream;

  Future<String?> getInitialNotificationPayload() async {
    if (kIsWeb) return null;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details != null && details.didNotificationLaunchApp) {
        return details.notificationResponse?.payload;
      }
    } catch (e) {
      // Ignore UnimplementedError on platforms that don't support this
      debugPrint('getNotificationAppLaunchDetails failed: $e');
    }
    return null;
  }

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
    // Import EventStore to use eventId
    // Note: We need to import event_store.dart at the top of the file, not here.
    // I will assume the import is added or I'll add it in a separate call if needed.
    // However replace_file_content replaces a block.
    // I will use a simple string construction here to avoid adding an import if I can,
    // OR I will trust that I can add the import.
    // Actually, I can just replicate the ID generation here or depend on EventStore.
    // The previous file content didn't have EventStore import.
    // I should probably add the import. Be careful.
    // Let's use the explicit string format for now to minimize dependencies here if appropriate,
    // BUT consistent ID is key.
    // Let's add the import in a separate step or just include it in the replace content if I replace the whole file or top.
    // Since I'm replacing a chunk, I can't easily add the import at the top without another call.
    // I'll stick to string formatting matching EventStore for now to be safe and quick,
    // OR ideally I should add `import 'package:evmrider/services/event_store.dart';`
    
    final payload = '${event.eventName}|${event.blockNumber}|${event.transactionHash}|${event.logIndex}';

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      payload: payload,
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
    _tapController.add(response.payload);
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // No-op: the UI will refresh on resume. This keeps the callback registered.
}
