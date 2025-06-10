import 'package:flutter/material.dart';
import 'package:evmrider/services/eventlistener.dart';
import 'dart:async';
import 'package:evmrider/models/event.dart';

class EventListenerScreen extends StatefulWidget {
  final EthereumEventService? eventService;

  const EventListenerScreen({super.key, this.eventService});

  @override
  _EventListenerScreenState createState() => _EventListenerScreenState();
}

class _EventListenerScreenState extends State<EventListenerScreen> {
  bool _isListening = false;
  final List<Event> _events = [];
  StreamSubscription? _eventSubscription;

  @override
  Widget build(BuildContext context) {
    if (widget.eventService == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Event Listener')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.settings, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Please configure your Ethereum settings first',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Event Listener'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(_isListening ? Icons.stop : Icons.play_arrow),
            onPressed: _toggleListening,
          ),
          IconButton(icon: Icon(Icons.clear), onPressed: _clearEvents),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            color: _isListening ? Colors.green[100] : Colors.grey[100],
            child: Row(
              children: [
                Icon(
                  _isListening
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _isListening ? Colors.green : Colors.grey,
                ),
                SizedBox(width: 8),
                Text(
                  _isListening ? 'Listening for events...' : 'Not listening',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isListening ? Colors.green[800] : Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _events.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_note, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No events captured yet',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        SizedBox(height: 8),
                        Text(
                          _isListening
                              ? 'Waiting for contract events...'
                              : 'Start listening to capture events',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _events.length,
                    itemBuilder: (context, index) {
                      final event = _events[index];
                      return Card(
                        margin: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ExpansionTile(
                          title: Text(
                            event.eventName,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Block: ${event.blockNumber} | Tx: ${event.transactionHash.substring(0, 10)}...',
                          ),
                          children: [
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Transaction Hash:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(event.transactionHash),
                                  SizedBox(height: 8),
                                  Text(
                                    'Block Number:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(event.blockNumber.toString()),
                                  SizedBox(height: 8),
                                  Text(
                                    'Event Data:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      event.data.toString(),
                                      style: TextStyle(fontFamily: 'monospace'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    try {
      _eventSubscription = widget.eventService!.listenToEvents().listen(
        (event) {
          setState(() {
            _events.insert(0, event);
          });
        },
        onError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error listening to events: $error')),
          );
          setState(() {
            _isListening = false;
          });
        },
      );
      setState(() {
        _isListening = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to start listening: $e')));
    }
  }

  Future<void> _stopListening() async {
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    setState(() {
      _isListening = false;
    });
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
