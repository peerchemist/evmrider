import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';

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

  static EthereumConfig? fromYaml(String yamlContent) {
    final doc = loadYaml(yamlContent);
    if (doc is! YamlMap) return null;

    final normalized = _normalizeYaml(doc);
    if (normalized is! Map<String, dynamic>) return null;

    final rawContractAddress = _readYamlScalar(yamlContent, 'contractAddress');
    final rpcEndpoint = _stringValue(normalized['rpcEndpoint']);
    final apiKeyValue = _stringValue(normalized['apiKey']);
    final apiKey = apiKeyValue.isEmpty ? null : apiKeyValue;
    final contractAddress = _stringValue(
      normalized['contractAddress'],
      rawFallback: rawContractAddress,
    );
    final contractAbi = _abiValue(normalized['contractAbi']);
    final eventsToListen = _stringListValue(normalized['eventsToListen']);
    final startBlock = _intValue(normalized['startBlock'], fallback: 0);
    final lastBlockValue = normalized.containsKey('lastBlock')
        ? normalized['lastBlock']
        : null;
    final lastBlock = lastBlockValue == null
        ? null
        : _intValue(lastBlockValue, fallback: 0);
    final pollIntervalSeconds = _intValue(
      normalized['pollIntervalSeconds'],
      fallback: 5,
    );
    final notificationsEnabled = _boolValue(
      normalized['notificationsEnabled'],
      fallback: true,
    );

    return EthereumConfig(
      rpcEndpoint: rpcEndpoint,
      apiKey: apiKey,
      contractAddress: contractAddress,
      contractAbi: contractAbi,
      eventsToListen: eventsToListen,
      startBlock: startBlock,
      lastBlock: lastBlock,
      pollIntervalSeconds: pollIntervalSeconds,
      notificationsEnabled: notificationsEnabled,
    );
  }

  static dynamic _normalizeYaml(dynamic value) {
    if (value is YamlMap) {
      return value.map(
        (key, value) => MapEntry(key.toString(), _normalizeYaml(value)),
      );
    }
    if (value is YamlList) {
      return value.map(_normalizeYaml).toList();
    }
    return value;
  }

  static String _stringValue(dynamic value, {String? rawFallback}) {
    if (value == null) return rawFallback ?? '';
    if (value is String) return value;
    if (rawFallback != null && rawFallback.isNotEmpty) return rawFallback;
    return value.toString();
  }

  static String _abiValue(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return jsonEncode(value);
  }

  static List<String> _stringListValue(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value
          .map((entry) => entry.toString().trim())
          .where((entry) => entry.isNotEmpty)
          .toList();
    }
    final raw = value.toString();
    if (raw.trim().isEmpty) return [];
    return raw
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
  }

  static int _intValue(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  static bool _boolValue(dynamic value, {bool fallback = true}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    final normalized = value.toString().trim().toLowerCase();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
    return fallback;
  }

  static String _readYamlScalar(String yamlContent, String key) {
    final pattern = RegExp(
      '^\\s*${RegExp.escape(key)}\\s*:\\s*(.+?)\\s*(?:#.*)?\$',
    );
    for (final line in const LineSplitter().convert(yamlContent)) {
      final match = pattern.firstMatch(line);
      if (match == null) continue;
      var raw = match.group(1)?.trim() ?? '';
      if (raw == '|' || raw == '>') return '';
      raw = _stripYamlQuotes(raw);
      return raw;
    }
    return '';
  }

  static String _stripYamlQuotes(String value) {
    if (value.length < 2) return value;
    final first = value[0];
    final last = value[value.length - 1];
    if (first == "'" && last == "'") {
      return value.substring(1, value.length - 1).replaceAll("''", "'");
    }
    if (first == '"' && last == '"') {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  String toYaml() {
    final buffer = StringBuffer();
    buffer.writeln('rpcEndpoint: $rpcEndpoint');
    if (apiKey != null) {
      buffer.writeln('apiKey: $apiKey');
    }
    buffer.writeln(
      "contractAddress: '${contractAddress.replaceAll("'", "''")}'",
    );

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
