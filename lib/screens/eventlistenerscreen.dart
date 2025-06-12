import 'package:flutter/material.dart';
import 'package:evmrider/services/eventlistener.dart';
import 'dart:async';
import 'package:evmrider/models/event.dart';
import 'package:evmrider/screens/setup.dart';

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
  StreamSubscription? _eventSubscription;

  final int _pollIntervalSeconds = 10; // 5-second default

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
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ExpansionTile(
            title: Text(
              event.eventName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Block: ${event.blockNumber} | Tx: ${event.transactionHash.substring(0, 10)}…',
            ),
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
        Text(event.transactionHash),
        const SizedBox(height: 8),
        const Text(
          'Block Number:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(event.blockNumber.toString()),
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
          child: Text(
            event.data.toString(),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleListening() async =>
      _isListening ? _stopListening() : _startListening();

  Future<void> _startListening() async {
    try {
      _eventSubscription = widget.eventService!
          .listen(pollInterval: Duration(seconds: _pollIntervalSeconds))
          .listen(
            (event) => setState(() => _events.insert(0, event)),
            onError: (error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error listening to events: $error')),
              );
              setState(() => _isListening = false);
            },
          );
      setState(() => _isListening = true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to start listening: $e')));
    }
  }

  Future<void> _stopListening() async {
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    setState(() => _isListening = false);
  }

  void _clearEvents() {
    setState(() {
      _events.clear();
    });
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }
}
