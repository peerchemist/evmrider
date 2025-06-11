import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';
import 'package:wallet/wallet.dart' show EthereumAddress;
import 'package:evmrider/models/config.dart';
import 'package:evmrider/models/event.dart';

// Default interval for HTTP polling mode.
const _defaultPollInterval = Duration(seconds: 5);

class EthereumEventService {
  final EthereumConfig _config;
  final http.Client _httpClient;

  late final Web3Client _client;
  late final DeployedContract _contract;

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
  Stream<Event> listen({Duration pollInterval = _defaultPollInterval}) {
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
      _startPolling(name, pollInterval, controller);
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
    int fromBlock = 22681184;

    final timer = Timer.periodic(interval, (t) async {
      try {
        final latest = await _client.getBlockNumber();
        if (fromBlock == 0) fromBlock = latest; // first tick
        if (latest < fromBlock) return; // nothing new yet

        final logs = await _client.getLogs(
          FilterOptions.events(
            contract: _contract,
            event: ev,
            fromBlock: BlockNum.exact(fromBlock),
            toBlock: BlockNum.exact(latest),
          ),
        );

        for (final fe in logs) {
          out.add(_decode(eventName, fe));
        }
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
    try {
      final n = (fe as dynamic).blockNumber ?? (fe as dynamic).block;
      return n is int ? n : int.tryParse(n.toString()) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // ───────────────────────────────────── cleanup ──
  void dispose() {
    _client.dispose();
    _httpClient.close();
  }
}
