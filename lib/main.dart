import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:evmrider/services/eventlistener.dart';
import 'package:evmrider/models/config.dart';
import 'package:evmrider/models/app_state.dart';
import 'package:evmrider/screens/eventlistenerscreen.dart';
import 'package:evmrider/screens/setup.dart';
import 'package:evmrider/utils/hive_init.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initHiveForApp();
  
  Hive.registerAdapter(EthereumConfigAdapter());
  Hive.registerAdapter(AppStateAdapter());

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
  EthereumConfig? _config;
  EthereumEventService? _eventService;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final cfg = await EthereumConfig.load();
    if (!mounted) return;

    if (cfg != null && cfg.isValid()) {
      _eventService?.dispose();
      setState(() {
        _config = cfg;
        _eventService = EthereumEventService(cfg);
      });
    }
  }

  /// Called by SetupScreen when the user presses “Save”.
  void _onConfigUpdated(EthereumConfig cfg) {
    setState(() {
      _config = cfg;
      _eventService?.dispose();
      _eventService = EthereumEventService(cfg);
    });
  }

  /// Opens the Setup screen.
  void _openSetup() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            SetupScreen(config: _config, onConfigUpdated: _onConfigUpdated),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return EventListenerScreen(
      eventService: _eventService,
      onOpenSettings: _openSetup, // << gear-icon callback
    );
  }

  @override
  void dispose() {
    _eventService?.dispose();
    super.dispose();
  }
}
