import 'package:flutter/material.dart';
import 'package:evmrider/services/eventlistener.dart';
import 'dart:async';
import 'package:evmrider/models/event.dart';
import 'package:evmrider/screens/setup.dart';
import 'package:evmrider/services/notifications.dart';
import 'package:url_launcher/url_launcher.dart';

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

class _EventListenerScreenState extends State<EventListenerScreen> {
  bool _isListening = false;
  final List<Event> _events = [];
  static const int _maxEvents = 200;
  StreamSubscription<Event>? _eventSubscription;
  int _tokenDecimals = 18;

  @override
  void initState() {
    super.initState();
    _resolveTokenDecimals();
  }

  @override
  void didUpdateWidget(covariant EventListenerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventService != widget.eventService) {
      setState(() => _tokenDecimals = 18);
      _resolveTokenDecimals();
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
        appBar: AppBar(title: const Text('EVM Event Listener')),
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
        title: const Text('EVM Event Listener'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings, // gear icon
            tooltip: 'Setup',
          ),
          IconButton(
            icon: Icon(_isListening ? Icons.stop : Icons.play_arrow),
            onPressed: _toggleListening,
          ),
          IconButton(icon: const Icon(Icons.clear), onPressed: _clearEvents),
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
            child: _events.isEmpty ? _buildEmptyState() : _buildEventList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
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
      ),
    );
  }

  Widget _buildEventList() {
    return ListView.builder(
      itemCount: _events.length,
      itemBuilder: (context, index) {
        final event = _events[index];
        final tx = event.transactionHash;
        final txPreview = tx.length <= 10 ? tx : '${tx.substring(0, 10)}…';
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ExpansionTile(
            title: Text(
              event.eventName,
              style: const TextStyle(fontWeight: FontWeight.bold),
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
        const Text(
          'Event Data:',
          style: TextStyle(fontWeight: FontWeight.bold),
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
    return InkWell(
      onTap: () => unawaited(_openTransactionLink(txHash)),
      mouseCursor: SystemMouseCursors.click,
      child: Text(
        txHash,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Future<void> _openTransactionLink(String txHash) async {
    final uri = Uri.parse('https://etherscan.io/tx/$txHash');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $uri')),
      );
    }
  }

  Widget _buildEventData(Map<String, dynamic> data) {
    if (data.isEmpty) {
      return const SelectableText(
        '{}',
        style: TextStyle(fontFamily: 'monospace'),
      );
    }

    final entries =
        data.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
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

  Future<void> _resolveTokenDecimals() async {
    final service = widget.eventService;
    if (service == null) return;

    final decimals = await service.getTokenDecimals();
    if (!mounted) return;
    setState(() => _tokenDecimals = decimals < 0 ? 0 : decimals);
  }

  String _formatEventValue(dynamic value) {
    if (value is List) {
      return '[${value.map(_formatEventValue).join(', ')}]';
    }
    final bigInt = _toBigInt(value);
    if (bigInt != null) {
      return _formatBigIntWithDecimals(bigInt, _tokenDecimals);
    }
    return value.toString();
  }

  BigInt? _toBigInt(dynamic value) {
    if (value is BigInt) return value;
    if (value is int) return BigInt.from(value);
    if (value is String) {
      final normalized = value.trim();
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

  String _buildDecimalString(
    bool isNegative,
    String intPart,
    String fracPart,
  ) {
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
          setState(() {
            _events.insert(0, event);
            if (_events.length > _maxEvents) {
              _events.removeRange(_maxEvents, _events.length);
            }
          });
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
    setState(() {
      _events.clear();
    });
  }

  @override
  void dispose() {
    unawaited(_stopListening(updateState: false));
    super.dispose();
  }
}
