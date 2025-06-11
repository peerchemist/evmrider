import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
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

  final _filterSubs = <StreamSubscription<dynamic>>[];
  final _pollTimers = <Timer>[];

  late final bool _useEthFilter;

  EthereumEventService(this._config, [http.Client? httpClient])
    : _httpClient = httpClient ?? http.Client() {
    _init();
  }

  // ─────────────────────────────────────────────────── init ──
  void _init() {
    final rpcUrl = _appendApiKey(_config.rpcEndpoint, _config.apiKey);
    _useEthFilter = rpcUrl.startsWith('ws');

    _client = _useEthFilter
        ? Web3Client(
            rpcUrl,
            _httpClient,
            // `WebSocketChannel.connect()` picks the right implementation
            // for mobile / desktop / Flutter web automatically.
            socketConnector: () => WebSocketChannel.connect(
              Uri.parse(rpcUrl),
            ).cast<String>(), // make sure the channel is <String>
          )
        : Web3Client(rpcUrl, _httpClient);

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

  Stream<Event> listen({Duration pollInterval = _defaultPollInterval}) {
    final controller = StreamController<Event>.broadcast(
      onCancel: () async {
        for (final s in _filterSubs) {
          await s.cancel();
        }
        for (final t in _pollTimers) {
          t.cancel();
        }
        _filterSubs.clear();
        _pollTimers.clear();
        dispose(); // free sockets + HTTP client
      },
    );

    for (final name in _config.eventsToListen) {
      final ev = _contract.event(name);

      if (_useEthFilter) {
        // WebSocket → real-time filters
        final sub = _client
            .events(FilterOptions.events(contract: _contract, event: ev))
            .listen(
              (fe) => controller.add(_decode(name, fe)),
              onError: controller.addError,
            );
        _filterSubs.add(sub);
      } else {
        // HTTP → start polling loop
        _startPolling(name, ev, pollInterval, controller);
      }
    }

    return controller.stream;
  }

  void _startPolling(
    String name,
    ContractEvent ev,
    Duration interval,
    StreamController<Event> out,
  ) {
    int fromBlock = 0;

    final timer = Timer.periodic(interval, (t) async {
      try {
        final latest = await _client.getBlockNumber();
        if (fromBlock == 0) fromBlock = latest; // first tick
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
          out.add(_decode(name, fe));
        }
        fromBlock = latest + 1;
      } catch (e) {
        out.addError(e);
      }
    });

    _pollTimers.add(timer);
  }

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

  // ─────────────────────────────────────────── cleanup ──
  void dispose() {
    _client.dispose();
    _httpClient.close();
  }
}
