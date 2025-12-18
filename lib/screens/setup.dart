import 'package:flutter/material.dart';
import 'package:evmrider/models/config.dart';
import 'dart:convert';
import 'dart:async';

class SetupScreen extends StatefulWidget {
  final EthereumConfig? config;
  final ValueChanged<EthereumConfig> onConfigUpdated;

  const SetupScreen({super.key, this.config, required this.onConfigUpdated});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  static final RegExp _ethAddressPattern = RegExp(r'^0x[a-fA-F0-9]{40}$');

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _rpcController;
  late TextEditingController _apiKeyController;
  late TextEditingController _contractController;
  late TextEditingController _abiController;
  late TextEditingController _startBlockController;
  late TextEditingController _pollIntervalController;
  List<String> _events = [];
  List<String> _availableEvents = [];
  Timer? _abiParseDebounce;
  bool _isSaving = false;

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
      text: widget.config?.startBlock.toString() ?? '',
    );
    _pollIntervalController = TextEditingController(
      text: widget.config?.pollIntervalSeconds.toString() ?? '',
    );
    _events = List.from(widget.config?.eventsToListen ?? []);
    _parseAbiForEvents(notify: false);
  }

  void _parseAbiForEvents({bool notify = true}) {
    final raw = _abiController.text.trim();
    if (raw.isEmpty) {
      _availableEvents = [];
      if (notify && mounted) setState(() {});
      return;
    }

    try {
      final abi = jsonDecode(raw);
      if (abi is! List) {
        _availableEvents = [];
        if (notify && mounted) setState(() {});
        return;
      }

      final events = <String>{};
      for (final entry in abi) {
        if (entry is! Map) continue;
        if (entry['type'] != 'event') continue;
        final name = entry['name'];
        if (name is String && name.trim().isNotEmpty) {
          events.add(name);
        }
      }

      _availableEvents = events.toList()..sort();
      if (notify && mounted) setState(() {});
    } catch (_) {
      _availableEvents = [];
      if (notify && mounted) setState(() {});
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
                          final uri = Uri.tryParse(value.trim());
                          if (uri == null || !uri.isAbsolute) {
                            return 'Please enter a valid URL';
                          }
                          if (uri.scheme != 'http' && uri.scheme != 'https') {
                            return 'RPC endpoint must start with http:// or https://';
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
                          labelText: 'Start block (optional)',
                          hintText: 'e.g. 19000000',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return null; // optional
                          }
                          final n = int.tryParse(value.trim());
                          if (n == null || n < 0) {
                            return 'Enter a valid block number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _pollIntervalController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Poll Interval (seconds) *',
                          hintText: 'e.g. 5',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter poll interval';
                          }
                          final n = int.tryParse(value.trim());
                          if (n == null || n <= 0) {
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
                          if (!_ethAddressPattern.hasMatch(value.trim())) {
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
                            jsonDecode(value.trim());
                            return null;
                          } catch (e) {
                            return 'Please enter valid JSON';
                          }
                        },
                        onChanged: (_) {
                          _abiParseDebounce?.cancel();
                          _abiParseDebounce = Timer(
                            const Duration(milliseconds: 400),
                            _parseAbiForEvents,
                          );
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
                onPressed: _isSaving ? null : _saveConfig,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(_isSaving ? 'Saving…' : 'Save Configuration'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveConfig() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    if (_events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one event to listen for'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final startBlock = int.tryParse(_startBlockController.text.trim());
    final pollInterval = int.tryParse(_pollIntervalController.text.trim());

    final config = EthereumConfig(
      rpcEndpoint: _rpcController.text.trim(),
      apiKey: _apiKeyController.text.trim().isEmpty
          ? null
          : _apiKeyController.text.trim(),
      contractAddress: _contractController.text.trim(),
      contractAbi: _abiController.text.trim(),
      eventsToListen: _events,
      startBlock: startBlock ?? 0,
      pollIntervalSeconds: pollInterval ?? 5,
    );

    try {
      await config.save();

      widget.onConfigUpdated(config);
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuration saved successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving configuration: $e')));
    }
  }

  @override
  void dispose() {
    _abiParseDebounce?.cancel();
    _rpcController.dispose();
    _apiKeyController.dispose();
    _contractController.dispose();
    _abiController.dispose();
    _startBlockController.dispose();
    _pollIntervalController.dispose();
    super.dispose();
  }
}
