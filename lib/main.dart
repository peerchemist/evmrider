import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:evmrider/services/eventlistener.dart';
import 'package:evmrider/models/config.dart';
import 'package:evmrider/screens/eventlistenerscreen.dart';
import 'package:evmrider/screens/setup.dart';
import 'package:evmrider/services/background_polling.dart';
import 'package:evmrider/utils/hive_init.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarColor: Colors.transparent,
    ),
  );
  await initHiveForApp();

  await BackgroundPollingService.initialize();

  runApp(EthereumEventListenerApp());
}

class EthereumEventListenerApp extends StatefulWidget {
  const EthereumEventListenerApp({super.key});

  @override
  State<EthereumEventListenerApp> createState() =>
      _EthereumEventListenerAppState();
}

class _EthereumEventListenerAppState extends State<EthereumEventListenerApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _resolveInitialTheme();
  }

  void _resolveInitialTheme() {
    final brightness = WidgetsBinding
        .instance
        .platformDispatcher
        .platformBrightness;
    _themeMode = brightness == Brightness.dark
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ethereum Event Listener',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD0BCFF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD0BCFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
          ),
        ),
      ),
      themeMode: _themeMode,
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
      unawaited(BackgroundPollingService.schedule(cfg.pollIntervalSeconds));
    } else {
      unawaited(BackgroundPollingService.cancel());
    }
  }

  /// Called by SetupScreen when the user presses “Save”.
  void _onConfigUpdated(EthereumConfig cfg) {
    setState(() {
      _config = cfg;
      _eventService?.dispose();
      _eventService = EthereumEventService(cfg);
    });
    unawaited(BackgroundPollingService.schedule(cfg.pollIntervalSeconds));
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

  Future<void> _loadShowcaseConfig() async {
    final contents = await rootBundle.loadString(
      'assets/configs/showcase_uniswap_v2_usdc_weth.yaml',
    );
    final config = EthereumConfig.fromYaml(contents);
    if (config == null) {
      throw Exception('Invalid showcase configuration.');
    }

    final seededConfig = await _seedShowcaseConfig(config);
    await seededConfig.save();
    if (!mounted) return;
    _onConfigUpdated(seededConfig);
  }

  Future<EthereumConfig> _seedShowcaseConfig(EthereumConfig config) async {
    try {
      final rpcUrl = _appendApiKey(config.rpcEndpoint, config.apiKey);
      final httpClient = http.Client();
      final client = Web3Client(rpcUrl, httpClient);
      try {
        final latest = await client.getBlockNumber();
        const seedOffset = 100;
        final seededLastBlock =
            latest > seedOffset ? latest - seedOffset : latest;
        return EthereumConfig(
          rpcEndpoint: config.rpcEndpoint,
          apiKey: config.apiKey,
          contractAddress: config.contractAddress,
          contractAbi: config.contractAbi,
          eventsToListen: config.eventsToListen,
          startBlock: config.startBlock,
          lastBlock: seededLastBlock,
          pollIntervalSeconds: config.pollIntervalSeconds,
          notificationsEnabled: config.notificationsEnabled,
          blockExplorerUrl: config.blockExplorerUrl,
        );
      } finally {
        client.dispose();
        httpClient.close();
      }
    } catch (_) {
      return config;
    }
  }

  String _appendApiKey(String url, String? apiKey) {
    if (apiKey == null || apiKey.isEmpty) return url;
    try {
      final uri = Uri.parse(url);
      return uri
          .replace(
            queryParameters: <String, String>{
              ...uri.queryParameters,
              'apikey': apiKey,
            },
          )
          .toString();
    } catch (_) {
      final sep = url.contains('?') ? '&' : '?';
      return '$url${sep}apikey=${Uri.encodeQueryComponent(apiKey)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return EventListenerScreen(
      eventService: _eventService,
      onOpenSettings: _openSetup, // << gear-icon callback
      onLoadShowcaseConfig: _loadShowcaseConfig,
    );
  }

  @override
  void dispose() {
    _eventService?.dispose();
    super.dispose();
  }
}
