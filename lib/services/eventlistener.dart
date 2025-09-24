import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';
import 'package:wallet/wallet.dart' show EthereumAddress;
import 'package:evmrider/models/config.dart';
import 'package:evmrider/models/event.dart';

class EthereumEventService {
  late EthereumConfig _config;
  final http.Client _httpClient;

  late final Web3Client _client;
  late final DeployedContract _contract;

  EthereumConfig get config => _config;

  /// Keep polling timers so we can cancel them on `dispose()`.
  final _timers = <Timer>[];

  EthereumEventService(this._config, [http.Client? httpClient])
    : _httpClient = httpClient ?? http.Client() {
    _init();
  }

  // ─────────────────────────────────────────────────── init ──
  void _init() {
    final rpcUrl = _appendApiKey(_config.rpcEndpoint, _config.apiKey);

    // Only http / https are accepted
    final uri = Uri.parse(rpcUrl);
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw ArgumentError.value(
        _config.rpcEndpoint,
        'rpcEndpoint',
        'Must start with http:// or https://',
      );
    }

    _client = Web3Client(rpcUrl, _httpClient);

    _contract = DeployedContract(
      ContractAbi.fromJson(_config.contractAbi, 'Contract'),
      EthereumAddress.fromHex(_config.contractAddress),
    );
  }

  String _appendApiKey(String url, String? apiKey) {
    if (apiKey == null || apiKey.isEmpty) return url;
    final sep = url.contains('?') ? '&' : '?';
    return '$url${sep}apikey=$apiKey';
  }

  // ───────────────────────────────────────── listen ──
  Stream<Event> listen() {
    final controller = StreamController<Event>.broadcast(
      onCancel: () async {
        for (final t in _timers) {
          t.cancel();
        }
        _timers.clear();
        dispose();
      },
    );

    for (final name in _config.eventsToListen) {
      _startPolling(
        name,
        Duration(seconds: _config.pollIntervalSeconds),
        controller,
      );
    }

    return controller.stream;
  }

  // ───────────────────────────────────── polling loop ──
  void _startPolling(
    String eventName,
    Duration interval,
    StreamController<Event> out,
  ) {
    final ev = _contract.event(eventName);

    // Starting point hierarchy: explicit startBlock > persisted lastBlock > 0
    int fromBlock = _config.startBlock;

    final timer = Timer.periodic(interval, (t) async {
      try {
        final latest = await _client.getBlockNumber();
        if (latest < fromBlock) return;

        final logs = await _client.getLogs(
          FilterOptions.events(
            contract: _contract,
            event: ev,
            fromBlock: BlockNum.exact(fromBlock),
            toBlock: BlockNum.exact(latest),
          ),
        );

        for (final fe in logs) {
          final event = _decode(eventName, fe);
          out.add(event);
          _maybeSaveLastBlock(event.blockNumber); // ← NEW
        }

        // Next window starts after what we just fetched
        fromBlock = latest + 1;
      } catch (e) {
        out.addError(e);
      }
    });

    _timers.add(timer);
  }

  // ───────────────────────────────────────── decode ──
  Event _decode(String name, FilterEvent fe) {
    final data = <String, dynamic>{};

    try {
      final ev = _contract.event(name);
      final topics = fe.topics?.whereType<String>().toList() ?? [];
      final decoded = ev.decodeResults(topics, fe.data ?? '');

      final inputs = _eventAbi(name)?['inputs'] as List<dynamic>? ?? [];
      for (var i = 0; i < decoded.length; i++) {
        final paramName = (i < inputs.length)
            ? (inputs[i] as Map<String, dynamic>)['name'] as String? ??
                  'param_$i'
            : 'param_$i';
        data[paramName] = decoded[i].toString();
      }
    } catch (e) {
      data
        ..['rawData'] = fe.data
        ..['topics'] = fe.topics
        ..['error'] = e.toString();
    }

    return Event(
      eventName: name,
      transactionHash: fe.transactionHash ?? 'unknown',
      blockNumber: _blockNumber(fe),
      data: data,
    );
  }

  Map<String, dynamic>? _eventAbi(String name) {
    final abi = jsonDecode(_config.contractAbi) as List<dynamic>;
    return abi.cast<Map<String, dynamic>>().firstWhere(
      (e) => e['type'] == 'event' && e['name'] == name,
      orElse: () => <String, dynamic>{},
    );
  }

  int _blockNumber(FilterEvent fe) {
    dynamic raw;

    try {
      raw = (fe as dynamic).blockNumber; // some forks
    } catch (_) {}
    if (raw == null) {
      try {
        raw = (fe as dynamic).block; // web3dart ≥2.4.1
      } catch (_) {}
    }
    if (raw == null) {
      try {
        raw = (fe as dynamic).blockNum; // web3dart 2.0 – 2.4.0
      } catch (_) {}
    }

    // Convert to int.
    if (raw is int) return raw;
    if (raw is BigInt) return raw.toInt();

    if (raw is String) {
      final s = raw.trim().toLowerCase();
      return int.parse(
        s.startsWith('0x') ? s.substring(2) : s,
        radix: s.startsWith('0x') ? 16 : 10,
      );
    }

    return 0; // unknown / absent
  }

  void dispose() {
    _client.dispose();
    _httpClient.close();
  }

  /// Store the highest block we’ve processed in shared_preferences.
  void _maybeSaveLastBlock(int blockNumber) async {
    if (blockNumber <= (_config.lastBlock ?? 0)) return; // nothing new

    _config = EthereumConfig(
      rpcEndpoint: _config.rpcEndpoint,
      apiKey: _config.apiKey,
      contractAddress: _config.contractAddress,
      contractAbi: _config.contractAbi,
      eventsToListen: _config.eventsToListen,
      startBlock: _config.startBlock,
      lastBlock: blockNumber, // updated
      pollIntervalSeconds: _config.pollIntervalSeconds,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ethereum_config', jsonEncode(_config.toJson()));
  }
}
