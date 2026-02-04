import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:evmrider/services/eventlistener.dart';
import 'dart:async';
import 'package:evmrider/models/event.dart';
import 'package:evmrider/screens/setup.dart';
import 'package:evmrider/screens/aboutscreen.dart';
import 'package:evmrider/services/notifications.dart';
import 'package:evmrider/services/event_store.dart';
import 'package:evmrider/screens/event_details_screen.dart';
import 'package:evmrider/models/config.dart';
import 'package:evmrider/utils/utils.dart';
import 'package:evmrider/utils/share_event.dart';
import 'package:evmrider/utils/event_value_formatter.dart';
import 'package:evmrider/widgets/event_data_display.dart';
import 'package:evmrider/widgets/blockchain_link.dart';
import 'package:evmrider/widgets/external_link.dart';

class EventListenerScreen extends StatefulWidget {
  final EthereumEventService? eventService;
  final VoidCallback? onOpenSettings;
  final Future<void> Function()? onLoadShowcaseConfig;

  const EventListenerScreen({
    super.key,
    this.eventService,
    this.onOpenSettings,
    this.onLoadShowcaseConfig,
  });

  @override
  State<EventListenerScreen> createState() => _EventListenerScreenState();
}

class _EventListenerScreenState extends State<EventListenerScreen>
    with WidgetsBindingObserver {
  bool _isListening = false;
  bool _isRefreshing = false;
  bool _isLoadingShowcase = false;
  String? _pendingNotificationPayload;
  static const int _maxEvents = 200;
  StreamSubscription<Event>? _eventSubscription;
  StreamSubscription<void>? _notificationTapSubscription;
  ValueListenable<Box>? _eventListenable;
  int _tokenDecimals = 18;
  static const String _appTitle = 'EVM Event Listener';
  EthereumConfig? get _config => widget.eventService?.config;

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(NotificationService.instance.ensureInitialized());
    _notificationTapSubscription = NotificationService
        .instance
        .onNotificationTap
        .listen(_handleNotificationTap);
    _resolveTokenDecimals();
    unawaited(_loadStoredEvents().then((_) => _checkInitialNotification()));
  }

  @override
  void didUpdateWidget(covariant EventListenerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventService != widget.eventService) {
      setState(() => _tokenDecimals = 18);
      _resolveTokenDecimals();
      unawaited(_loadStoredEvents());
      final pending = _pendingNotificationPayload;
      if (pending != null && widget.eventService != null) {
        _pendingNotificationPayload = null;
        unawaited(_openNotificationPayload(pending));
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadStoredEvents());
    }
  }

  void _openSettings() {
    if (widget.onOpenSettings != null) {
      widget.onOpenSettings!();
      return;
    }
    // Fallback: push SetupScreen ourselves.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SetupScreen(
          config: null,
          onConfigUpdated: (_) => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  Future<void> _loadShowcaseConfig() async {
    final loader = widget.onLoadShowcaseConfig;
    if (loader == null || _isLoadingShowcase) return;

    setState(() => _isLoadingShowcase = true);
    try {
      await loader();
      _showSnack('Showcase configuration loaded.');
    } catch (e) {
      _showSnack('Failed to load showcase: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingShowcase = false);
      }
    }
  }

  Future<void> _openNotificationPayload(String? payload) async {
    if (!mounted || payload == null) return;

    final config = _config ?? await EthereumConfig.load();
    if (config == null || !config.isValid()) {
      _pendingNotificationPayload = payload;
      return;
    }

    final event = await EventStore.findById(
      payload,
      preferredConfig: config,
      limitPerKey: _maxEvents,
    );
    if (event == null || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EventDetailsScreen(
            event: event,
            tokenDecimals: _tokenDecimals,
            config: config,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.eventService == null) {
      return Scaffold(
        appBar: AppBar(title: _buildScrollableTitle(_appTitle)),
        body: SafeArea(
          top: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 72,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Please configure your settings first',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.orange[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Setup steps:',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        '1) Open Setup and enter the RPC endpoint, contract address, and ABI.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          const Text('2) You can find RPC endpoints at '),
                          const ExternalLink(
                            label: 'chainlist.org',
                            url: 'https://chainlist.org',
                          ),
                          const Text(' (Ethereum Mainnet).'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          const Text('3) Copy the contract ABI from '),
                          const ExternalLink(
                            label: 'etherscan.io',
                            url: 'https://etherscan.io',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.settings),
                    label: const Text('Open setup'),
                    onPressed: _openSettings, // ← always works
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(
                      _isLoadingShowcase
                          ? 'Loading showcase…'
                          : 'Load showcase config',
                    ),
                    onPressed:
                        (widget.onLoadShowcaseConfig == null ||
                            _isLoadingShowcase)
                        ? null
                        : _loadShowcaseConfig,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ============== Normal listener UI ===========================
    return Scaffold(
      appBar: AppBar(
        title: _buildScrollableTitle(_appTitle),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AboutScreen())),
            tooltip: 'About',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings, // gear icon
            tooltip: 'Setup',
          ),
          IconButton(
            icon: Icon(_isListening ? Icons.stop : Icons.play_arrow),
            onPressed: _toggleListening,
            tooltip: _isListening ? 'Stop listening' : 'Start listening',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearEvents,
            tooltip: 'Clear events',
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // status / polling-interval bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: _isListening ? Colors.green[100] : Colors.grey[100],
              child: Row(
                children: [
                  Icon(
                    _isListening
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: _isListening ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isListening ? 'Listening for events…' : 'Not listening',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _isListening ? Colors.green[800] : Colors.grey[800],
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            // event list
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshEvents,
                child: _buildEventList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollableTitle(String text) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Text(text),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.event_note, size: 64, color: Colors.grey),
        const SizedBox(height: 16),
        Text(
          'No events captured yet',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          _isListening
              ? 'Waiting for contract events…'
              : 'Start listening to capture events',
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildRefreshableEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: _buildEmptyState()),
          ),
        );
      },
    );
  }

  static int _compareEvents(Event a, Event b) {
    final blockCompare = b.blockNumber.compareTo(a.blockNumber);
    if (blockCompare != 0) return blockCompare;
    final logCompare = b.logIndex.compareTo(a.logIndex);
    if (logCompare != 0) return logCompare;
    return b.transactionHash.compareTo(a.transactionHash);
  }

  Widget _buildEventTile(Event event) {
    final tx = event.transactionHash;
    final txPreview = tx.length <= 10 ? tx : '${tx.substring(0, 10)}…';
    final card = Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                event.eventName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (!isMobilePlatform)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete',
                onPressed: () => _removeEvent(event),
              ),
          ],
        ),
        subtitle: Text('Block: ${event.blockNumber} | Tx: $txPreview'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildEventDetails(event),
          ),
        ],
      ),
    );
    if (!isMobilePlatform) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onSecondaryTapUp: (details) =>
            _showEventContextMenu(event, details.globalPosition),
        child: card,
      );
    }
    return Dismissible(
      key: ValueKey(EventStore.eventId(event)),
      direction: DismissDirection.startToEnd,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red[400],
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _removeEvent(event),
      child: card,
    );
  }

  Widget _buildEventList() {
    if (_eventListenable == null) return _buildEmptyState();

    return ValueListenableBuilder<Box>(
      valueListenable: _eventListenable!,
      builder: (context, box, _) {
        final events = EventStore.loadSync(
          box,
          _config,
          limit: _maxEvents,
        );
        events.sort(_compareEvents);

        if (events.isEmpty) {
          return _buildRefreshableEmptyState();
        }

        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: events.length,
          itemBuilder: (context, index) {
            return _buildEventTile(events[index]);
          },
        );
      },
    );
  }

  Widget _buildEventDetails(Event event) {
    final blockExplorerUrl =
        _config?.blockExplorerUrl ?? 'https://etherscan.io';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Transaction Hash:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        TransactionLink(
          txHash: event.transactionHash,
          blockExplorerUrl: blockExplorerUrl,
        ),
        const SizedBox(height: 8),
        const Text(
          'Block Number:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SelectableText(event.blockNumber.toString()),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text(
              'Event Data:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: shouldCopyTextOnThisPlatform()
                  ? 'Copy event data'
                  : 'Share event data',
              onPressed: () => unawaited(_shareEventData(event)),
            ),
          ],
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
          child: EventDataDisplay(
            data: event.data,
            tokenDecimals: _tokenDecimals,
          ),
        ),
      ],
    );
  }

  Future<void> _shareEventData(Event event) async {
    final text = formatEventDataForShare(
      event.eventName,
      event.data,
      tokenDecimals: _tokenDecimals,
    );
    await shareOrCopyText(
      context: context,
      text: text,
      subject: 'Event data',
      copiedToast: 'Event data copied',
    );
  }

  Future<void> _resolveTokenDecimals() async {
    final service = widget.eventService;
    if (service == null) return;

    final decimals = await service.getTokenDecimals();
    if (!mounted) return;
    setState(() => _tokenDecimals = decimals < 0 ? 0 : decimals);
  }

  Future<void> _loadStoredEvents() async {
    final config = _config;
    if (config == null) {
      if (!mounted) return;
      setState(() {
        _eventListenable = null;
      });
      return;
    }

    await EventStore.closeBox();
    final listenable = await EventStore.getValueListenable(config);
    if (!mounted) return;
    setState(() {
      _eventListenable = listenable;
    });
  }

  Future<void> _refreshEvents() async {
    final service = widget.eventService;
    if (service == null) return;
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    try {
      final config = service.config;
      final events = await service.pollOnce();
      if (events.isNotEmpty) {
        final existingEvents = await EventStore.load(
          config,
          limit: _maxEvents,
        );
        final existingIds = existingEvents.map(EventStore.eventId).toSet();
        final freshEvents = events
            .where((event) => !existingIds.contains(EventStore.eventId(event)))
            .toList();
        if (config.notificationsEnabled && freshEvents.isNotEmpty) {
          for (final event in freshEvents) {
            unawaited(
              NotificationService.instance.notifyEvent(event, silent: true),
            );
          }
        }
        await EventStore.addEvents(
          config,
          events,
          maxEvents: _maxEvents,
        );
        if (!mounted) return;
        // No need to manually merge, listener handles it
      }
    } catch (e) {
      _showSnack('Refresh failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _toggleListening() async =>
      _isListening ? _stopListening() : _startListening();

  Future<void> _startListening() async {
    final service = widget.eventService;
    if (service == null) return;
    if (_isListening) return;

    try {
      await NotificationService.instance.requestPermissionsIfNeeded();
      await _eventSubscription?.cancel();
      _eventSubscription = service.listen().listen(
        (event) {
          if (!mounted) return;
          if (service.config.notificationsEnabled) {
            unawaited(NotificationService.instance.notifyEvent(event));
          }
          unawaited(
            EventStore.addEvent(
              service.config,
              event,
              maxEvents: _maxEvents,
            ),
          );
          // No need to manually merge, listener handles it
        },
        onError: (Object error, StackTrace st) {
          if (!mounted) return;
          _showSnack('Error listening to events: $error');
          unawaited(_stopListening());
        },
      );
      if (!mounted) return;
      setState(() => _isListening = true);
    } catch (e) {
      _showSnack('Failed to start listening: $e');
    }
  }

  Future<void> _stopListening({bool updateState = true}) async {
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    if (updateState && mounted) {
      setState(() => _isListening = false);
    } else {
      _isListening = false;
    }
  }

  void _clearEvents() {
    unawaited(EventStore.clear(_config));
    // No need to clear local list manually
  }

  void _removeEvent(Event event) {
    unawaited(EventStore.removeEvent(_config, event));
    // No need to remove from local list manually
  }

  Future<void> _showEventContextMenu(Event event, Offset globalPosition) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(globalPosition, globalPosition),
        Offset.zero & overlay.size,
      ),
      items: const [PopupMenuItem(value: 'remove', child: Text('Remove'))],
    );
    if (selected == 'remove') {
      _removeEvent(event);
    }
  }

  Future<void> _checkInitialNotification() async {
    final payload = await NotificationService.instance
        .getInitialNotificationPayload();
    if (payload != null) {
      _handleNotificationTap(payload);
    }
  }

  void _handleNotificationTap(String? payload) {
    unawaited(_openNotificationPayload(payload));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationTapSubscription?.cancel();
    unawaited(_stopListening(updateState: false));
    super.dispose();
  }
}
