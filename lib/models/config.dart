import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class EthereumConfig {
  final String rpcEndpoint;
  final String? apiKey;
  final String contractAddress;
  final String contractAbi;
  final List<String> eventsToListen;
  final int startBlock;
  final int? lastBlock;
  final int pollIntervalSeconds;
  final bool notificationsEnabled;

  EthereumConfig({
    required this.rpcEndpoint,
    this.apiKey,
    required this.contractAddress,
    required this.contractAbi,
    required this.eventsToListen,
    this.startBlock = 0,
    this.lastBlock,
    this.pollIntervalSeconds = 5,
    this.notificationsEnabled = true,
  });

  bool isValid() {
    return rpcEndpoint.isNotEmpty &&
        contractAddress.isNotEmpty &&
        contractAbi.isNotEmpty &&
        eventsToListen.isNotEmpty;
  }

  Map<String, dynamic> toJson() => {
    'rpcEndpoint': rpcEndpoint,
    'apiKey': apiKey,
    'contractAddress': contractAddress,
    'contractAbi': contractAbi,
    'eventsToListen': eventsToListen,
    'startBlock': startBlock,
    'lastBlock': lastBlock,
    'pollIntervalSeconds': pollIntervalSeconds,
    'notificationsEnabled': notificationsEnabled,
  };

  factory EthereumConfig.fromJson(Map<String, dynamic> json) => EthereumConfig(
    rpcEndpoint: json['rpcEndpoint'] ?? '',
    apiKey: json['apiKey'],
    contractAddress: json['contractAddress'] ?? '',
    contractAbi: json['contractAbi'] ?? '',
    eventsToListen: List<String>.from(json['eventsToListen'] ?? []),
    startBlock: json['startBlock'] ?? 0,
    lastBlock: json['lastBlock'] ?? 0,
    pollIntervalSeconds: json['pollIntervalSeconds'] ?? 5,
    notificationsEnabled: json['notificationsEnabled'] ?? true,
  );

  String toYaml() {
    final buffer = StringBuffer();
    buffer.writeln('rpcEndpoint: $rpcEndpoint');
    if (apiKey != null) {
      buffer.writeln('apiKey: $apiKey');
    }
    buffer.writeln('contractAddress: $contractAddress');

    // Format ABI for YAML block scalar
    String formattedAbi = contractAbi;
    try {
      final decoded = jsonDecode(contractAbi);
      formattedAbi = const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      // If it's not valid JSON, just use as is
    }

    buffer.writeln('contractAbi: |');
    for (final line in formattedAbi.split('\n')) {
      buffer.writeln('  $line');
    }

    buffer.writeln('eventsToListen:');
    for (final event in eventsToListen) {
      buffer.writeln('  - $event');
    }
    buffer.writeln('startBlock: $startBlock');
    if (lastBlock != null) {
      buffer.writeln('lastBlock: $lastBlock');
    }
    buffer.writeln('pollIntervalSeconds: $pollIntervalSeconds');
    buffer.writeln('notificationsEnabled: $notificationsEnabled');
    return buffer.toString();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ethereum_config', jsonEncode(toJson()));
  }

  static Future<EthereumConfig?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final configStr = prefs.getString('ethereum_config');
    if (configStr != null) {
      return EthereumConfig.fromJson(jsonDecode(configStr));
    }
    return null;
  }
}
