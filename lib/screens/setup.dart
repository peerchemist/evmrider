import 'package:flutter/material.dart';
import 'package:evmrider/models/config.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SetupScreen extends StatefulWidget {
  final EthereumConfig? config;
  final Function(EthereumConfig) onConfigUpdated;

  const SetupScreen({super.key, this.config, required this.onConfigUpdated});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _rpcController;
  late TextEditingController _apiKeyController;
  late TextEditingController _contractController;
  late TextEditingController _abiController;
  late TextEditingController _startBlockController;
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
    _startBlockController = TextEditingController(
      text: widget.config?.startBlock?.toString() ?? '',
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
                          hintText: 'https://eth.llamarpc.com',
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
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _startBlockController,
                        keyboardType: TextInputType
                            .number, // ← here (not inside decoration)
                        decoration: const InputDecoration(
                          labelText: 'Start block *',
                          hintText: 'e.g. 19000000',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return null; // optional
                          }
                          final n = int.tryParse(value.trim());
                          if (n == null || n < 0) {
                            return 'Enter a positive integer';
                          }
                          return null;
                        },
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
    if (!_formKey.currentState!.validate()) return;

    if (_events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one event to listen for'),
        ),
      );
      return;
    }

    final startBlock = int.tryParse(_startBlockController.text.trim());

    final config = EthereumConfig(
      rpcEndpoint: _rpcController.text.trim(),
      apiKey: _apiKeyController.text.trim().isEmpty
          ? null
          : _apiKeyController.text.trim(),
      contractAddress: _contractController.text.trim(),
      contractAbi: _abiController.text.trim(),
      eventsToListen: _events,
      startBlock: startBlock,
    );

    try {
      await config.save(); // ≤— assuming your model already persists itself

      // ─ Also stash the raw values in shared_preferences ─
      final prefs = await SharedPreferences.getInstance();
      prefs
        ..setString('rpcEndpoint', config.rpcEndpoint)
        ..setString('apiKey', config.apiKey ?? '')
        ..setString('contractAddress', config.contractAddress)
        ..setString('contractAbi', config.contractAbi)
        ..setStringList('eventsToListen', _events);

      // only set the int when we actually have one
      if (startBlock != null) {
        await prefs.setInt('startBlock', startBlock);
      } else {
        await prefs.remove('startBlock');
      }

      widget.onConfigUpdated(config);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuration saved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving configuration: $e')));
    }
  }

  @override
  void dispose() {
    _rpcController.dispose();
    _apiKeyController.dispose();
    _contractController.dispose();
    _abiController.dispose();
    _startBlockController.dispose();
    super.dispose();
  }
}
