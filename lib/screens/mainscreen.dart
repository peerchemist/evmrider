import 'package:evmrider/models/config.dart';
import 'package:flutter/material.dart';
import 'package:evmrider/services/eventlistener.dart';
import 'package:evmrider/screens/setup.dart';
import 'package:evmrider/screens/eventlistenerscreen.dart';

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
    if (!mounted) return;
    setState(() {
      _config = config;
      _setEventServiceFromConfig(config);
    });
  }

  void _onConfigUpdated(EthereumConfig config) {
    setState(() {
      _config = config;
      _setEventServiceFromConfig(config);
      _selectedIndex = 1;
    });
  }

  void _setEventServiceFromConfig(EthereumConfig? config) {
    _eventService?.dispose();
    if (config != null && config.isValid()) {
      _eventService = EthereumEventService(config);
    } else {
      _eventService = null;
    }
  }

  void _openSetupTab() {
    setState(() => _selectedIndex = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          SetupScreen(config: _config, onConfigUpdated: _onConfigUpdated),
          EventListenerScreen(
            eventService: _eventService,
            onOpenSettings: _openSetupTab,
          ),
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

  @override
  void dispose() {
    _eventService?.dispose();
    super.dispose();
  }
}
