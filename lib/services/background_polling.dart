import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import 'package:evmrider/models/config.dart';
import 'package:evmrider/models/event.dart';
import 'package:evmrider/models/app_state.dart';
import 'package:evmrider/services/eventlistener.dart';
import 'package:evmrider/services/event_store.dart';
import 'package:evmrider/services/notifications.dart';
import 'package:evmrider/utils/hive_init.dart';
import 'package:evmrider/utils/utils.dart';

const String kBackgroundPollTask = 'com.peerchemist.evmrider.backgroundPoll';
const int _maxStoredEvents = 200;

class BackgroundPollingService {
  static Future<void> initialize() async {
    if (!isMobilePlatform) return;
    await Workmanager().initialize(callbackDispatcher);
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
  return seconds.clamp(900, 3600);
}

/// Timeout for the entire background task to prevent indefinite hangs.
const Duration _taskTimeout = Duration(seconds: 60);

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      return await _runBackgroundPoll().timeout(
        _taskTimeout,
        onTimeout: () {
          debugPrint('Background poll timed out after $_taskTimeout');
          return true;
        },
      );
    } catch (e, st) {
      // Top-level safety net — should never reach here but guarantees no crash
      debugPrint('Background poll fatal error: $e\n$st');
      return true;
    }
  });
}

/// The actual background polling logic, separated for clarity and testability.
Future<bool> _runBackgroundPoll() async {
  // ─────────────────────────────── Initialization ───────────────────────────
  try {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
  } catch (e) {
    debugPrint('Background poll: Flutter binding init failed: $e');
    return true;
  }

  try {
    await initHiveForApp();
  } catch (e) {
    debugPrint('Background poll: Hive init failed: $e');
    return true;
  }

  // ─────────────────────────────── Load config & state ──────────────────────
  EthereumConfig? config;
  AppState? state;
  try {
    config = await EthereumConfig.load();
    state = await AppState.load();
  } catch (e) {
    debugPrint('Background poll: Config/State load failed: $e');
    return true;
  }

  if (config == null || !config.isValid()) {
    debugPrint('Background poll: No valid config');
    return true;
  }

  // ─────────────────────────────── Poll events ──────────────────────────────
  EthereumEventService? service;
  List<Event> events = const [];

  try {
    service = EthereumEventService(config);
    events = await service.pollOnce();

    // Success! Reset failure count.
    if (state.backgroundPollFailures != 0) {
      state.backgroundPollFailures = 0;
      await state.save();
    }
  } catch (e) {
    debugPrint('Background poll: Event polling failed: $e');
    service?.dispose();

    // Increment failure count and notify if needed
    final currentFailures = (state.backgroundPollFailures ?? 0) + 1;
    state.backgroundPollFailures = currentFailures;
    await state.save();

    if (currentFailures >= 3) {
      try {
        await NotificationService.instance.notifySimple(
          title: 'Background Polling Issue',
          body:
              'Background polling has failed $currentFailures times in a row. '
              'Please check your network connection or RPC settings.',
        );
      } catch (ne) {
        debugPrint('Background poll: Failed to notify error: $ne');
      }
    }

    return true;
  }

  if (events.isEmpty) {
    service.dispose();
    return true;
  }

  // ─────────────────────── Deduplicate & persist ────────────────────────────
  List<Event> freshEvents = const [];
  try {
    final existingEvents = await EventStore.load(
      config,
      limit: _maxStoredEvents,
    );
    final existingIds = existingEvents.map(EventStore.eventId).toSet();
    freshEvents = events
        .where((event) => !existingIds.contains(EventStore.eventId(event)))
        .toList(growable: false);

    await EventStore.addEvents(config, events, maxEvents: _maxStoredEvents);
  } catch (e) {
    debugPrint('Background poll: Event store failed: $e');
    // continue to dispose service below
  }

  // ─────────────────────────────── Notifications ────────────────────────────
  if (config.notificationsEnabled && freshEvents.isNotEmpty) {
    for (final event in freshEvents) {
      try {
        await NotificationService.instance.notifyEvent(event);
      } catch (e) {
        debugPrint('Background poll: Notification failed for event: $e');
        // continue with remaining events
      }
    }
  }

  // ─────────────────────────────── Cleanup ──────────────────────────────────
  try {
    service.dispose();
  } catch (e) {
    debugPrint('Background poll: Service dispose failed: $e');
  }

  return true;
}
