import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce/hive.dart';
import 'package:evmrider/services/eventlistener.dart';
import 'dart:async';
import 'package:evmrider/models/event.dart';
import 'package:evmrider/screens/setup.dart';
import 'package:evmrider/screens/aboutscreen.dart';
import 'package:evmrider/services/notifications.dart';
import 'package:evmrider/services/event_store.dart';
import 'package:evmrider/screens/event_details_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:evmrider/utils/utils.dart';
import 'package:evmrider/utils/share_event.dart';
import 'package:evmrider/utils/block_explorer.dart';
import 'package:wallet/wallet.dart' as wallet;

class EventListenerScreen extends StatefulWidget {
  final EthereumEventService? eventService;
  final VoidCallback? onOpenSettings;

  const EventListenerScreen({
    super.key,
    this.eventService,
    this.onOpenSettings,
  });

  @override
  State<EventListenerScreen> createState() => _EventListenerScreenState();
}

class _EventListenerScreenState extends State<EventListenerScreen>
    with WidgetsBindingObserver {
  bool _isListening = false;
  bool _isRefreshing = false;
  static const int _maxEvents = 200;
  StreamSubscription<Event>? _eventSubscription;
  StreamSubscription<void>? _notificationTapSubscription;
  ValueListenable<Box>? _eventListenable;
  int _tokenDecimals = 18;
  static const String _appTitle = 'EVM Event Listener';

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

  @override
  Widget build(BuildContext context) {
    if (widget.eventService == null) {
      return Scaffold(
        appBar: AppBar(title: _buildScrollableTitle(_appTitle)),
        body: Center(
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
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.settings),
                  label: const Text('Open setup'),
                  onPressed: _openSettings, // ← always works
                ),
              ],
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
      body: Column(
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

  Widget _buildEventList() {
    if (_eventListenable == null) return _buildEmptyState();

    return ValueListenableBuilder<Box>(
      valueListenable: _eventListenable!,
      builder: (context, box, _) {
        final events = EventStore.loadSync(
          box,
          widget.eventService?.config,
          limit: _maxEvents,
        );
        
        // Update local cache for other operations if needed, or just use this list.
        // We'll trust this list for rendering.
        // Note: We might want to sort here if loadSync doesn't guarantee it, 
        // but loadSync calls _decodeEvents which just decodes.
        // EventStore.addEvents sorts. 
        // Let's sort to be safe as per original _sortEvents logic.
        events.sort((a, b) {
          final blockCompare = b.blockNumber.compareTo(a.blockNumber);
          if (blockCompare != 0) return blockCompare;
          final logCompare = b.logIndex.compareTo(a.logIndex);
          if (logCompare != 0) return logCompare;
          return b.transactionHash.compareTo(a.transactionHash);
        });

        if (events.isEmpty) {
          return _buildRefreshableEmptyState();
        }

        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
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
          },
        );
      },
    );
  }

  Widget _buildEventDetails(Event event) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Transaction Hash:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        _buildTransactionLink(event.transactionHash),
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
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(4),
          ),
          child: _buildEventData(event.data),
        ),
      ],
    );
  }

  Widget _buildTransactionLink(String txHash) {
    final theme = Theme.of(context);
    final explorer = BlockExplorer(
      widget.eventService?.config.blockExplorerUrl ?? 'https://etherscan.io',
    );
    final link = explorer.transactionLink(txHash);

    return InkWell(
      onTap: () => unawaited(_openTransactionLink(link)),
      onLongPress: () => unawaited(_copyLink(link)),
      onSecondaryTap: () => unawaited(_copyLink(link)),
      mouseCursor: SystemMouseCursors.click,
      child: Row(
        children: [
          Expanded(
            child: Text(
              txHash,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                decoration: TextDecoration.underline,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openTransactionLink(String url) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open $uri')));
    }
  }

  Future<void> _copyLink(String url) async {
    maybeHapticFeedback();
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link copied')));
  }

  Future<void> _shareEventData(Event event) async {
    final text = _formatEventDataForShare(event);
    await shareOrCopyText(
      context: context,
      text: text,
      subject: 'Event data',
      copiedToast: 'Event data copied',
    );
  }

  Widget _buildEventData(Map<String, dynamic> data) {
    if (data.isEmpty) {
      return const SelectableText(
        '{}',
        style: TextStyle(fontFamily: 'monospace'),
      );
    }

    final entries = data.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    _formatEventValue(entry.value),
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  String _formatEventDataForShare(Event event) {
    final data = event.data;
    final header = 'Event: ${event.eventName}';
    if (data.isEmpty) return '$header\n{}';
    final entries = data.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final body = entries
        .map((entry) => '${entry.key}: ${_formatEventValue(entry.value)}')
        .join('\n');
    return '$header\n$body';
  }

  Future<void> _resolveTokenDecimals() async {
    final service = widget.eventService;
    if (service == null) return;

    final decimals = await service.getTokenDecimals();
    if (!mounted) return;
    setState(() => _tokenDecimals = decimals < 0 ? 0 : decimals);
  }

  Future<void> _loadStoredEvents() async {
    final config = widget.eventService?.config;
    if (config == null) {
      if (!mounted) return;
      setState(() {
        _eventListenable = null;
      });
      return;
    }

    // Force reload from disk to catch background updates
    await EventStore.closeBox();
    final listenable = await EventStore.getValueListenable(config);
    if (!mounted) return;
    setState(() {
      _eventListenable = listenable;
    });
    // Trigger initial load via listener or just let builder handle it?
    // We still need _events for other methods like _handleNotificationTap to verify existence if we want.
    // But if we switch to builder, _events might be stale if we don't update it.
    // Let's defer _events population to the builder or keep it for now?
    // If I use builder, I don't need to manually populate _events here for display.
    // user wants: "list of events get re-read" "every time app is opened"
    // The builder will do that.
  }

  Future<void> _refreshEvents() async {
    final service = widget.eventService;
    if (service == null) return;
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    try {
      final events = await service.pollOnce();
      if (events.isNotEmpty) {
        final existingEvents = await EventStore.load(service.config, limit: _maxEvents);
        final existingIds = existingEvents.map(EventStore.eventId).toSet();
        final freshEvents = events
            .where((event) => !existingIds.contains(EventStore.eventId(event)))
            .toList();
        if ((service.config.notificationsEnabled) && freshEvents.isNotEmpty) {
          for (final event in freshEvents) {
            unawaited(
              NotificationService.instance.notifyEvent(event, silent: true),
            );
          }
        }
        await EventStore.addEvents(
          service.config,
          events,
          maxEvents: _maxEvents,
        );
        if (!mounted) return;
        // No need to manually merge, listener handles it
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Refresh failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  String _formatEventValue(dynamic value) {
    if (value is List) {
      return '[${value.map(_formatEventValue).join(', ')}]';
    }
    final address = _formatAddressValue(value);
    if (address != null) {
      return address;
    }
    if (value is String) {
      final normalized = value.trim();
      if (normalized.startsWith('0x') || normalized.startsWith('0X')) {
        return normalized;
      }
    }
    final bigInt = _toBigInt(value);
    if (bigInt != null) {
      return _formatBigIntWithDecimals(bigInt, _tokenDecimals);
    }
    return value.toString();
  }

  String? _formatAddressValue(dynamic value) {
    if (value is wallet.EthereumAddress) {
      return value.with0x.toLowerCase();
    }
    if (value is String) {
      return normalizeHexAddress(value);
    }
    final dynamic dyn = value;
    try {
      final hex = dyn.hex;
      if (hex is String && (hex.startsWith('0x') || hex.startsWith('0X'))) {
        return hex.toLowerCase();
      }
    } catch (_) {
      // Ignore non-address values.
    }
    try {
      final hexEip55 = dyn.hexEip55;
      if (hexEip55 is String &&
          (hexEip55.startsWith('0x') || hexEip55.startsWith('0X'))) {
        return hexEip55.toLowerCase();
      }
    } catch (_) {
      // Ignore non-address values.
    }
    return null;
  }

  BigInt? _toBigInt(dynamic value) {
    if (value is BigInt) return value;
    if (value is int) return BigInt.from(value);
    if (value is String) {
      final normalized = value.trim();
      if (normalized.startsWith('0x') || normalized.startsWith('0X')) {
        return null;
      }
      if (RegExp(r'^-?\d+$').hasMatch(normalized)) {
        return BigInt.tryParse(normalized);
      }
    }
    return null;
  }

  String _formatBigIntWithDecimals(BigInt value, int decimals) {
    if (decimals <= 0) return value.toString();
    final isNegative = value.isNegative;
    final raw = value.abs().toString();

    if (raw.length <= decimals) {
      final padded = raw.padLeft(decimals + 1, '0');
      final intPart = padded.substring(0, padded.length - decimals);
      final fracPart = _trimTrailingZeros(
        padded.substring(padded.length - decimals),
      );
      return _buildDecimalString(isNegative, intPart, fracPart);
    }

    final intPart = raw.substring(0, raw.length - decimals);
    final fracPart = _trimTrailingZeros(raw.substring(raw.length - decimals));
    return _buildDecimalString(isNegative, intPart, fracPart);
  }

  String _buildDecimalString(bool isNegative, String intPart, String fracPart) {
    final sign = isNegative ? '-' : '';
    if (fracPart.isEmpty) return '$sign$intPart';
    return '$sign$intPart.$fracPart';
  }

  String _trimTrailingZeros(String value) {
    var end = value.length;
    while (end > 0 && value[end - 1] == '0') {
      end--;
    }
    return value.substring(0, end);
  }

  Future<void> _toggleListening() async =>
      _isListening ? _stopListening() : _startListening();

  Future<void> _startListening() async {
    if (widget.eventService == null) return;
    if (_isListening) return;

    try {
      await NotificationService.instance.requestPermissionsIfNeeded();
      await _eventSubscription?.cancel();
      _eventSubscription = widget.eventService!.listen().listen(
        (event) {
          if (!mounted) return;
          if (widget.eventService?.config.notificationsEnabled ?? true) {
            unawaited(NotificationService.instance.notifyEvent(event));
          }
          unawaited(
            EventStore.addEvent(
              widget.eventService?.config,
              event,
              maxEvents: _maxEvents,
            ),
          );
          // No need to manually merge, listener handles it
        },
        onError: (Object error, StackTrace st) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error listening to events: $error')),
          );
          unawaited(_stopListening());
        },
      );
      if (!mounted) return;
      setState(() => _isListening = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to start listening: $e')));
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
    unawaited(EventStore.clear(widget.eventService?.config));
    // No need to clear local list manually
  }

  void _removeEvent(Event event) {
    unawaited(EventStore.removeEvent(widget.eventService?.config, event));
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
    final payload = await NotificationService.instance.getInitialNotificationPayload();
    if (payload != null) {
      _handleNotificationTap(payload);
    }
  }

  void _handleNotificationTap(String? payload) {
    unawaited(_loadStoredEvents().then((_) async {
      if (!mounted || payload == null) return;
      
      try {
        final config = widget.eventService?.config;
        final events = await EventStore.load(config, limit: _maxEvents);
        final event = events.firstWhere(
          (e) => EventStore.eventId(e) == payload,
        );
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
      } catch (e) {
        // Event not found, possibly cleared or limit reached.
        // Just staying on the list is fine, user will see the latest state.
      }
    }));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationTapSubscription?.cancel();
    unawaited(_stopListening(updateState: false));
    super.dispose();
  }
}
