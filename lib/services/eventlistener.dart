import 'package:web3dart/web3dart.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:wallet/wallet.dart' show EthereumAddress;
import 'dart:async';
import 'package:evmrider/models/config.dart';
import 'package:evmrider/models/event.dart';

class EthereumEventService {
  final EthereumConfig config;
  late Web3Client _client;
  late DeployedContract _contract;

  EthereumEventService(this.config) {
    _initializeClient();
  }

  void _initializeClient() {
    String rpcUrl = config.rpcEndpoint;
    if (config.apiKey != null && config.apiKey!.isNotEmpty) {
      if (rpcUrl.contains('?')) {
        rpcUrl += '&apikey=${config.apiKey}';
      } else {
        rpcUrl += '?apikey=${config.apiKey}';
      }
    }

    _client = Web3Client(rpcUrl, http.Client());

    final abi = jsonDecode(config.contractAbi);
    _contract = DeployedContract(
      ContractAbi.fromJson(jsonEncode(abi), 'Contract'),
      EthereumAddress.fromHex(config.contractAddress),
    );
  }

  Stream<Event> listenToEvents() async* {
    // Create separate streams for each event and merge them
    final eventStreams = config.eventsToListen.map((eventName) {
      final contractEvent = _contract.event(eventName);
      return _client.events(
        FilterOptions.events(contract: _contract, event: contractEvent),
      );
    }).toList();

    // Merge all event streams into one
    final StreamController<FilterEvent> controller =
        StreamController<FilterEvent>();
    final subscriptions = <StreamSubscription>[];

    for (final stream in eventStreams) {
      final subscription = stream.listen(
        (event) => controller.add(event),
        onError: (error) => controller.addError(error),
      );
      subscriptions.add(subscription);
    }

    // Clean up subscriptions when the stream is cancelled
    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
      await controller.close();
    };

    await for (final filterEvent in controller.stream) {
      // Parse the event data manually since the API structure changed
      final eventData = <String, dynamic>{};
      final eventName = _getEventNameFromTopics(filterEvent.topics);

      if (eventName != null) {
        // Try to decode the event data
        try {
          final contractEvent = _contract.event(eventName);

          // Convert nullable string list to non-nullable
          final topics =
              filterEvent.topics?.whereType<String>().toList() ?? <String>[];
          final data = filterEvent.data ?? '';

          // Decode event data
          final decodedData = contractEvent.decodeResults(topics, data);

          // Get event parameters from ABI
          final eventAbi = _getEventAbiFromName(eventName);
          if (eventAbi != null && eventAbi['inputs'] != null) {
            final inputs = eventAbi['inputs'] as List;
            for (int i = 0; i < inputs.length && i < decodedData.length; i++) {
              final input = inputs[i] as Map<String, dynamic>;
              eventData[input['name'] ?? 'param_$i'] = decodedData[i]
                  .toString();
            }
          } else {
            // Fallback: use indexed parameters
            for (int i = 0; i < decodedData.length; i++) {
              eventData['param_$i'] = decodedData[i].toString();
            }
          }
        } catch (e) {
          // Fallback: use raw data
          eventData['rawData'] = filterEvent.data ?? '';
          eventData['topics'] =
              filterEvent.topics?.whereType<String>().toList() ?? [];
          eventData['error'] = e.toString();
        }

        yield Event(
          eventName: eventName,
          transactionHash: filterEvent.transactionHash ?? 'unknown',
          blockNumber: _getBlockNumber(filterEvent),
          data: eventData,
        );
      }
    }
  }

  String? _getEventNameFromTopics(List<String?>? topics) {
    if (topics == null || topics.isEmpty) return null;

    final eventSignature = topics[0];
    if (eventSignature == null) return null;

    // Try to match the event signature with our configured events
    for (final eventName in config.eventsToListen) {
      try {
        _contract.event(eventName);
        // Get the event signature hash
        final eventAbi = _getEventAbiFromName(eventName);
        if (eventAbi != null) {
          // Simple comparison - in a real implementation you'd calculate the keccak256 hash
          return eventName;
        }
      } catch (e) {
        continue;
      }
    }

    return config.eventsToListen.isNotEmpty
        ? config.eventsToListen.first
        : 'UnknownEvent';
  }

  Map<String, dynamic>? _getEventAbiFromName(String eventName) {
    try {
      final abi = jsonDecode(config.contractAbi) as List;
      return abi.firstWhere(
            (item) => item['type'] == 'event' && item['name'] == eventName,
            orElse: () => null,
          )
          as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  int _getBlockNumber(FilterEvent filterEvent) {
    // Try different ways to get block number based on available properties
    try {
      // Check if blockNumber property exists
      final dynamic blockNum = (filterEvent as dynamic).blockNumber;
      if (blockNum != null) {
        return blockNum is int
            ? blockNum
            : int.tryParse(blockNum.toString()) ?? 0;
      }
    } catch (e) {
      // Property doesn't exist or access failed
    }

    try {
      // Check if block property exists
      final dynamic block = (filterEvent as dynamic).block;
      if (block != null) {
        return block is int ? block : int.tryParse(block.toString()) ?? 0;
      }
    } catch (e) {
      // Property doesn't exist or access failed
    }

    return 0; // Fallback
  }

  void dispose() {
    _client.dispose();
  }
}
