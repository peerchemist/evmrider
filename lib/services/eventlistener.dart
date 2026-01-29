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
  final bool _ownsHttpClient;

  late final Web3Client _client;
  late final DeployedContract _contract;
  late final Map<String, List<String>> _eventParamNamesByEvent;
  late final bool _hasDecimalsFunction;
  int? _tokenDecimals;

  StreamController<Event>? _controller;
  bool _disposed = false;

  EthereumConfig get config => _config;

  /// Keep polling timers so we can cancel them on `dispose()`.
  final _timers = <Timer>[];

  EthereumEventService(this._config, [http.Client? httpClient])
    : _httpClient = httpClient ?? http.Client(),
      _ownsHttpClient = httpClient == null {
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

    _eventParamNamesByEvent = _buildEventParamNamesByEvent(_config.contractAbi);
    _hasDecimalsFunction = _abiHasDecimalsFunction(_config.contractAbi);

    _contract = DeployedContract(
      ContractAbi.fromJson(_config.contractAbi, 'Contract'),
      EthereumAddress.fromHex(_config.contractAddress),
    );
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

  // ───────────────────────────────────────── listen ──
  Stream<Event> listen() {
    if (_disposed) {
      throw StateError('EthereumEventService has been disposed.');
    }

    _controller ??= StreamController<Event>.broadcast(
      onListen: _startAllPolling,
      onCancel: _stopAllPolling,
    );

    return _controller!.stream;
  }

  void _startAllPolling() {
    if (_timers.isNotEmpty) return;

    final controller = _controller;
    if (controller == null || controller.isClosed) return;

    for (final name in _config.eventsToListen) {
      _startPolling(
        name,
        Duration(seconds: _config.pollIntervalSeconds),
        controller,
      );
    }
  }

  void _stopAllPolling() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  // ───────────────────────────────────── polling loop ──
  void _startPolling(
    String eventName,
    Duration interval,
    StreamController<Event> out,
  ) {
    final contractEvent = _contract.event(eventName);
    final paramNames = _eventParamNamesByEvent[eventName] ?? const <String>[];

    // Start from explicit startBlock if provided; otherwise continue from lastBlock.
    final hasExplicitStart = _config.startBlock > 0;
    int fromBlock;
    if (hasExplicitStart) {
      fromBlock = _config.startBlock;
    } else if ((_config.lastBlock ?? 0) > 0) {
      fromBlock = (_config.lastBlock ?? 0) + 1;
    } else {
      fromBlock = 0;
    }

    var inFlight = false;

    final timer = Timer.periodic(interval, (t) async {
      if (out.isClosed || _disposed) {
        t.cancel();
        return;
      }
      if (inFlight) return;
      inFlight = true;

      try {
        final latest = await _client.getBlockNumber();
        if (latest < fromBlock) return;

        final logs = await _client.getLogs(
          FilterOptions.events(
            contract: _contract,
            event: contractEvent,
            fromBlock: BlockNum.exact(fromBlock),
            toBlock: BlockNum.exact(latest),
          ),
        );

        for (final fe in logs) {
          final event = _decode(eventName, contractEvent, paramNames, fe);
          if (!out.isClosed) out.add(event);
        }

        unawaited(_maybeSaveLastBlock(latest));

        // Next window starts after what we just fetched
        fromBlock = latest + 1;
      } catch (e, st) {
        if (!out.isClosed) {
          out.addError(EthereumEventServiceException(eventName, e), st);
        }
      } finally {
        inFlight = false;
      }
    });

    _timers.add(timer);
  }

  // ───────────────────────────────────────── decode ──
  Event _decode(
    String name,
    ContractEvent ev,
    List<String> paramNames,
    FilterEvent fe,
  ) {
    final data = <String, dynamic>{};

    try {
      final topics = fe.topics?.whereType<String>().toList() ?? [];
      final decoded = ev.decodeResults(topics, fe.data ?? '');

      for (var i = 0; i < decoded.length; i++) {
        final paramName =
            i < paramNames.length && paramNames[i].trim().isNotEmpty
            ? paramNames[i]
            : 'param_$i';
        data[paramName] = decoded[i];
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

  Map<String, List<String>> _buildEventParamNamesByEvent(String contractAbi) {
    try {
      final abi = jsonDecode(contractAbi);
      if (abi is! List) return const <String, List<String>>{};

      final out = <String, List<String>>{};
      for (final entry in abi) {
        if (entry is! Map) continue;
        if (entry['type'] != 'event') continue;
        final name = entry['name'];
        if (name is! String || name.isEmpty) continue;

        final inputs = entry['inputs'];
        if (inputs is! List) continue;

        final paramNames = <String>[];
        for (final input in inputs) {
          if (input is Map && input['name'] is String) {
            paramNames.add(input['name'] as String);
          } else {
            paramNames.add('');
          }
        }
        out[name] = paramNames;
      }
      return out;
    } catch (_) {
      return const <String, List<String>>{};
    }
  }

  bool _abiHasDecimalsFunction(String contractAbi) {
    try {
      final abi = jsonDecode(contractAbi);
      if (abi is! List) return false;
      for (final entry in abi) {
        if (entry is! Map) continue;
        if (entry['type'] != 'function') continue;
        if (entry['name'] == 'decimals') return true;
      }
    } catch (_) {}
    return false;
  }

  Future<int> getTokenDecimals() async {
    if (_tokenDecimals != null) return _tokenDecimals!;
    if (!_hasDecimalsFunction) {
      _tokenDecimals = 18;
      return _tokenDecimals!;
    }

    try {
      final function = _contract.function('decimals');
      final result = await _client.call(
        contract: _contract,
        function: function,
        params: const [],
      );
      if (result.isNotEmpty) {
        final value = result.first;
        if (value is int) {
          _tokenDecimals = value;
          return value;
        }
        if (value is BigInt) {
          final asInt = value.toInt();
          _tokenDecimals = asInt;
          return asInt;
        }
        if (value is String) {
          final asInt = int.tryParse(value);
          if (asInt != null) {
            _tokenDecimals = asInt;
            return asInt;
          }
        }
      }
    } catch (_) {
      // best-effort; fall back below
    }

    _tokenDecimals = 18;
    return _tokenDecimals!;
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
    if (_disposed) return;
    _disposed = true;

    _stopAllPolling();
    unawaited(_controller?.close());

    _client.dispose();
    if (_ownsHttpClient) _httpClient.close();
  }

  /// Store the highest block we’ve processed in shared_preferences.
  Future<void> _maybeSaveLastBlock(int blockNumber) async {
    try {
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
        notificationsEnabled: _config.notificationsEnabled,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ethereum_config', jsonEncode(_config.toJson()));
    } catch (_) {
      // best-effort persistence
    }
  }
}

class EthereumEventServiceException implements Exception {
  final String eventName;
  final Object error;

  EthereumEventServiceException(this.eventName, this.error);

  @override
  String toString() => 'EthereumEventServiceException($eventName): $error';
}
