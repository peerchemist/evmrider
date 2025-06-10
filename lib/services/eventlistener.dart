import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';

import 'package:wallet/wallet.dart' show EthereumAddress;
import 'package:evmrider/models/config.dart';
import 'package:evmrider/models/event.dart';

class EthereumEventService {
  final EthereumConfig _config;
  final http.Client _httpClient;
  late final Web3Client _client;
  late final DeployedContract _contract;

  /// Optionally inject an existing [http.Client] – useful for testing or
  /// sharing a single client instance across services.
  EthereumEventService(this._config, [http.Client? httpClient])
    : _httpClient = httpClient ?? http.Client() {
    _init();
  }

  void _init() {
    final rpcUrl = _appendApiKey(_config.rpcEndpoint, _config.apiKey);
    _client = Web3Client(rpcUrl, _httpClient);

    final abi = jsonDecode(_config.contractAbi) as List<dynamic>;
    _contract = DeployedContract(
      ContractAbi.fromJson(jsonEncode(abi), 'Contract'),
      EthereumAddress.fromHex(_config.contractAddress),
    );
  }

  /// Adds the `apikey` query parameter when an api‑key is configured.
  String _appendApiKey(String url, String? apiKey) {
    if (apiKey == null || apiKey.isEmpty) return url;
    final sep = url.contains('?') ? '&' : '?';
    return '$url${sep}apikey=$apiKey';
  }

  /// Returns a broadcast [Stream] with decoded contract events.
  Stream<Event> listen() {
    final controller = StreamController<Event>.broadcast(onCancel: dispose);

    // Create a subscription per configured event.
    for (final name in _config.eventsToListen) {
      final ev = _contract.event(name);

      _client
          .events(FilterOptions.events(contract: _contract, event: ev))
          .listen(
            (filterEvent) => controller.add(_decode(name, filterEvent)),
            onError: controller.addError,
          );
    }

    return controller.stream;
  }

  /// Decodes a single [FilterEvent] into the domain‑specific [Event] class.
  Event _decode(String name, FilterEvent fe) {
    final data = <String, dynamic>{};

    try {
      final ev = _contract.event(name);
      final topics =
          fe.topics?.whereType<String>().toList(growable: false) ?? [];
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

  /// Frees network resources.
  void dispose() {
    _client.dispose();
    _httpClient.close();
  }
}
