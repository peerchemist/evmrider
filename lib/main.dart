import 'dart:async';
import 'package:flutter/material.dart';
import 'package:evmrider/services/eventlistener.dart';
import 'package:evmrider/models/config.dart';
import 'package:evmrider/screens/eventlistenerscreen.dart';
import 'package:evmrider/screens/setup.dart';

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
  State<MainScreen> createState() => _MainScreenState();
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
