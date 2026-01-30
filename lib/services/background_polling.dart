import 'package:flutter/widgets.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'package:evmrider/models/app_state.dart';
import 'package:evmrider/models/config.dart';
import 'package:evmrider/services/eventlistener.dart';
import 'package:evmrider/services/event_store.dart';
import 'package:evmrider/services/notifications.dart';
import 'package:evmrider/utils/utils.dart';

const String kBackgroundPollTask = 'com.peerchemist.evmrider.backgroundPoll';

class BackgroundPollingService {
  static Future<void> initialize() async {
    if (!isMobilePlatform) return;
    await Workmanager().initialize(
      callbackDispatcher,
    );
  }

  static Future<void> schedule(int intervalSeconds) async {
    if (!isMobilePlatform) return;
    final normalized = _clampMobileInterval(intervalSeconds);
    await Workmanager().registerPeriodicTask(
      kBackgroundPollTask,
      kBackgroundPollTask,
      frequency: Duration(seconds: normalized),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  static Future<void> cancel() async {
    if (!isMobilePlatform) return;
    await Workmanager().cancelByUniqueName(kBackgroundPollTask);
  }
}

int _clampMobileInterval(int seconds) {
  final clamped = seconds.clamp(900, 3600);
  return clamped.toInt();
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    await Hive.initFlutter();
    try {
      Hive.registerAdapter(EthereumConfigAdapter());
    } catch (_) {}
    try {
      Hive.registerAdapter(AppStateAdapter());
    } catch (_) {}

    final config = await EthereumConfig.load();
    if (config == null || !config.isValid()) {
      return true;
    }

    final service = EthereumEventService(config);
    try {
      final events = await service.pollOnce();
      if (events.isNotEmpty) {
        await EventStore.addEvents(config, events);
      }
      if (config.notificationsEnabled) {
        for (final event in events) {
          await NotificationService.instance.notifyEvent(event);
        }
      }
    } catch (_) {
      return true;
    } finally {
      service.dispose();
    }

    return true;
  });
}
