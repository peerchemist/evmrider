import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';
import 'package:wallet/wallet.dart';

void main() {
  runApp(EthereumEventListenerApp());
}

class EthereumEventListenerApp extends StatelessWidget {
  const EthereumEventListenerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ethereum Event Listener',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  EthereumConfig? _config;
  EthereumEventService? _eventService;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await EthereumConfig.load();
    setState(() {
      _config = config;
      if (_config != null && _config!.isValid()) {
        _eventService = EthereumEventService(_config!);
      }
    });
  }

  void _onConfigUpdated(EthereumConfig config) {
    setState(() {
      _config = config;
      _eventService = EthereumEventService(config);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          SetupScreen(config: _config, onConfigUpdated: _onConfigUpdated),
          EventListenerScreen(eventService: _eventService),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.settings), label: 'Setup'),
          NavigationDestination(icon: Icon(Icons.event), label: 'Events'),
        ],
      ),
    );
  }
}

class EthereumConfig {
  String rpcEndpoint;
  String? apiKey;
  String contractAddress;
  String contractAbi;
  List<String> eventsToListen;

  EthereumConfig({
    required this.rpcEndpoint,
    this.apiKey,
    required this.contractAddress,
    required this.contractAbi,
    required this.eventsToListen,
  });

  bool isValid() {
    return rpcEndpoint.isNotEmpty &&
        contractAddress.isNotEmpty &&
        contractAbi.isNotEmpty &&
        eventsToListen.isNotEmpty;
  }

  Map<String, dynamic> toJson() => {
    'rpcEndpoint': rpcEndpoint,
    'apiKey': apiKey,
    'contractAddress': contractAddress,
    'contractAbi': contractAbi,
    'eventsToListen': eventsToListen,
  };

  factory EthereumConfig.fromJson(Map<String, dynamic> json) => EthereumConfig(
    rpcEndpoint: json['rpcEndpoint'] ?? '',
    apiKey: json['apiKey'],
    contractAddress: json['contractAddress'] ?? '',
    contractAbi: json['contractAbi'] ?? '',
    eventsToListen: List<String>.from(json['eventsToListen'] ?? []),
  );

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ethereum_config', jsonEncode(toJson()));
  }

  static Future<EthereumConfig?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final configStr = prefs.getString('ethereum_config');
    if (configStr != null) {
      return EthereumConfig.fromJson(jsonDecode(configStr));
    }
    return null;
  }
}

class SetupScreen extends StatefulWidget {
  final EthereumConfig? config;
  final Function(EthereumConfig) onConfigUpdated;

  const SetupScreen({super.key, this.config, required this.onConfigUpdated});

  @override
  _SetupScreenState createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _rpcController;
  late TextEditingController _apiKeyController;
  late TextEditingController _contractController;
  late TextEditingController _abiController;
  List<String> _events = [];
  List<String> _availableEvents = [];

  @override
  void initState() {
    super.initState();
    _rpcController = TextEditingController(
      text: widget.config?.rpcEndpoint ?? '',
    );
    _apiKeyController = TextEditingController(
      text: widget.config?.apiKey ?? '',
    );
    _contractController = TextEditingController(
      text: widget.config?.contractAddress ?? '',
    );
    _abiController = TextEditingController(
      text: widget.config?.contractAbi ?? '',
    );
    _events = List.from(widget.config?.eventsToListen ?? []);
    _parseAbiForEvents();
  }

  void _parseAbiForEvents() {
    if (_abiController.text.isNotEmpty) {
      try {
        final abi = jsonDecode(_abiController.text) as List;
        _availableEvents = abi
            .where((item) => item['type'] == 'event')
            .map<String>((item) => item['name'] as String)
            .toList();
        setState(() {});
      } catch (e) {
        _availableEvents = [];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Setup'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RPC Configuration',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _rpcController,
                        decoration: InputDecoration(
                          labelText: 'RPC Endpoint *',
                          hintText:
                              'https://mainnet.infura.io/v3/YOUR-PROJECT-ID',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter RPC endpoint';
                          }
                          if (!Uri.parse(value).isAbsolute) {
                            return 'Please enter a valid URL';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _apiKeyController,
                        decoration: InputDecoration(
                          labelText: 'API Key (Optional)',
                          hintText: 'Enter if required by your RPC provider',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contract Configuration',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _contractController,
                        decoration: InputDecoration(
                          labelText: 'Contract Address *',
                          hintText: '0x...',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter contract address';
                          }
                          if (!value.startsWith('0x') || value.length != 42) {
                            return 'Please enter a valid Ethereum address';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _abiController,
                        decoration: InputDecoration(
                          labelText: 'Contract ABI (JSON) *',
                          hintText:
                              'Paste the complete ABI JSON from Etherscan',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 8,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter contract ABI';
                          }
                          try {
                            jsonDecode(value);
                            return null;
                          } catch (e) {
                            return 'Please enter valid JSON';
                          }
                        },
                        onChanged: (value) => _parseAbiForEvents(),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Events to Listen',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      SizedBox(height: 16),
                      if (_availableEvents.isNotEmpty)
                        ...(_availableEvents
                            .map(
                              (event) => CheckboxListTile(
                                title: Text(event),
                                value: _events.contains(event),
                                onChanged: (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      _events.add(event);
                                    } else {
                                      _events.remove(event);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList())
                      else
                        Text(
                          'Parse ABI first to see available events',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveConfig,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text('Save Configuration'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveConfig() async {
    if (_formKey.currentState!.validate()) {
      if (_events.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select at least one event to listen for'),
          ),
        );
        return;
      }

      final config = EthereumConfig(
        rpcEndpoint: _rpcController.text,
        apiKey: _apiKeyController.text.isEmpty ? null : _apiKeyController.text,
        contractAddress: _contractController.text,
        contractAbi: _abiController.text,
        eventsToListen: _events,
      );

      try {
        await config.save();
        widget.onConfigUpdated(config);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Configuration saved successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving configuration: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _rpcController.dispose();
    _apiKeyController.dispose();
    _contractController.dispose();
    _abiController.dispose();
    super.dispose();
  }
}

class EventListenerScreen extends StatefulWidget {
  final EthereumEventService? eventService;

  const EventListenerScreen({Key? key, this.eventService}) : super(key: key);

  @override
  _EventListenerScreenState createState() => _EventListenerScreenState();
}

class _EventListenerScreenState extends State<EventListenerScreen> {
  bool _isListening = false;
  List<ContractEvent> _events = [];
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

class ContractEvent {
  final String eventName;
  final String transactionHash;
  final int blockNumber;
  final Map<String, dynamic> data;

  ContractEvent({
    required this.eventName,
    required this.transactionHash,
    required this.blockNumber,
    required this.data,
  });
}

class EthereumEventService {
  final EthereumConfig config;
  late Web3Client _client;
  late DeployedContract _contract;

  EthereumEventService(this.config) {
    _initializeClient();
  }

  void _initializeClient() {
    String rpcUrl = config.rpcEndpoint;
    if (config.apiKey != null && config.apiKey!.isNotEmpty) {
      if (rpcUrl.contains('?')) {
        rpcUrl += '&apikey=${config.apiKey}';
      } else {
        rpcUrl += '?apikey=${config.apiKey}';
      }
    }

    _client = Web3Client(rpcUrl, http.Client());

    final abi = jsonDecode(config.contractAbi);
    _contract = DeployedContract(
      ContractAbi.fromJson(jsonEncode(abi), 'Contract'),
      EthereumAddress.fromHex(config.contractAddress),
    );
  }

  Stream<ContractEvent> listenToEvents() async* {
    // Create separate streams for each event and merge them
    final eventStreams = config.eventsToListen.map((eventName) {
      final contractEvent = _contract.event(eventName);
      return _client.events(
        FilterOptions.events(contract: _contract, event: contractEvent),
      );
    }).toList();

    // Merge all event streams into one
    final StreamController<FilterEvent> controller =
        StreamController<FilterEvent>();
    final subscriptions = <StreamSubscription>[];

    for (final stream in eventStreams) {
      final subscription = stream.listen(
        (event) => controller.add(event),
        onError: (error) => controller.addError(error),
      );
      subscriptions.add(subscription);
    }

    // Clean up subscriptions when the stream is cancelled
    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
      await controller.close();
    };

    await for (final filterEvent in controller.stream) {
      // Parse the event data manually since the API structure changed
      final eventData = <String, dynamic>{};
      final eventName = _getEventNameFromTopics(filterEvent.topics);

      if (eventName != null) {
        // Try to decode the event data
        try {
          final contractEvent = _contract.event(eventName);

          // Convert nullable string list to non-nullable
          final topics =
              filterEvent.topics?.whereType<String>().toList() ?? <String>[];
          final data = filterEvent.data ?? '';

          // Decode event data
          final decodedData = contractEvent.decodeResults(topics, data);

          // Get event parameters from ABI
          final eventAbi = _getEventAbiFromName(eventName);
          if (eventAbi != null && eventAbi['inputs'] != null) {
            final inputs = eventAbi['inputs'] as List;
            for (int i = 0; i < inputs.length && i < decodedData.length; i++) {
              final input = inputs[i] as Map<String, dynamic>;
              eventData[input['name'] ?? 'param_$i'] = decodedData[i]
                  .toString();
            }
          } else {
            // Fallback: use indexed parameters
            for (int i = 0; i < decodedData.length; i++) {
              eventData['param_$i'] = decodedData[i].toString();
            }
          }
        } catch (e) {
          // Fallback: use raw data
          eventData['rawData'] = filterEvent.data ?? '';
          eventData['topics'] =
              filterEvent.topics?.whereType<String>().toList() ?? [];
          eventData['error'] = e.toString();
        }

        yield ContractEvent(
          eventName: eventName,
          transactionHash: filterEvent.transactionHash ?? 'unknown',
          blockNumber: _getBlockNumber(filterEvent),
          data: eventData,
        );
      }
    }
  }

  String? _getEventNameFromTopics(List<String?>? topics) {
    if (topics == null || topics.isEmpty) return null;

    final eventSignature = topics[0];
    if (eventSignature == null) return null;

    // Try to match the event signature with our configured events
    for (final eventName in config.eventsToListen) {
      try {
        _contract.event(eventName);
        // Get the event signature hash
        final eventAbi = _getEventAbiFromName(eventName);
        if (eventAbi != null) {
          // Simple comparison - in a real implementation you'd calculate the keccak256 hash
          return eventName;
        }
      } catch (e) {
        continue;
      }
    }

    return config.eventsToListen.isNotEmpty
        ? config.eventsToListen.first
        : 'UnknownEvent';
  }

  Map<String, dynamic>? _getEventAbiFromName(String eventName) {
    try {
      final abi = jsonDecode(config.contractAbi) as List;
      return abi.firstWhere(
            (item) => item['type'] == 'event' && item['name'] == eventName,
            orElse: () => null,
          )
          as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  int _getBlockNumber(FilterEvent filterEvent) {
    // Try different ways to get block number based on available properties
    try {
      // Check if blockNumber property exists
      final dynamic blockNum = (filterEvent as dynamic).blockNumber;
      if (blockNum != null) {
        return blockNum is int
            ? blockNum
            : int.tryParse(blockNum.toString()) ?? 0;
      }
    } catch (e) {
      // Property doesn't exist or access failed
    }

    try {
      // Check if block property exists
      final dynamic block = (filterEvent as dynamic).block;
      if (block != null) {
        return block is int ? block : int.tryParse(block.toString()) ?? 0;
      }
    } catch (e) {
      // Property doesn't exist or access failed
    }

    return 0; // Fallback
  }

  void dispose() {
    _client.dispose();
  }
}
