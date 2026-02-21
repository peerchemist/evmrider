import 'dart:convert';
import 'dart:typed_data';

import 'package:evmrider/utils/event_value_formatter.dart';

class Event {
  final String eventName;
  final String transactionHash;
  final int blockNumber;
  final int logIndex;
  final int timestamp;
  final Map<String, dynamic> data;

  Event({
    required this.eventName,
    required this.transactionHash,
    required this.blockNumber,
    required this.logIndex,
    required this.timestamp,
    required this.data,
  });

  Map<String, dynamic> toJson() {
    return {
      'eventName': eventName,
      'transactionHash': transactionHash,
      'blockNumber': blockNumber,
      'logIndex': logIndex,
      'timestamp': timestamp,
      'data': _encodeValue(data),
    };
  }

  String toPrettyJson() {
    return const JsonEncoder.withIndent('  ').convert(toJson());
  }

  String toShareString({int tokenDecimals = 18}) {
    final formatter = EventValueFormatter(tokenDecimals: tokenDecimals);
    final lines = <String>[
      'Event: $eventName',
      'transactionHash: $transactionHash',
      'blockNumber: $blockNumber',
      'logIndex: $logIndex',
      'timestamp: ${DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true).toIso8601String()}',
    ];

    if (data.isEmpty) {
      lines.add('data: {}');
      return lines.join('\n');
    }

    final entries = data.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final entry in entries) {
      final keyLower = entry.key.toLowerCase();
      final value = keyLower == 'from' || keyLower == 'to'
          ? _stringifyRawValue(entry.value)
          : _stringifyDataValue(entry.value, formatter);
      lines.add('${entry.key}: $value');
    }

    return lines.join('\n');
  }

  static dynamic _encodeValue(dynamic value) {
    if (value == null) return null;
    if (value is num || value is bool || value is String) return value;
    if (value is BigInt) return value.toString();
    if (value is Uint8List) return value.toList();
    if (value is List) return value.map(_encodeValue).toList();
    if (value is Map) {
      final out = <String, dynamic>{};
      value.forEach((key, item) {
        out[key.toString()] = _encodeValue(item);
      });
      return out;
    }
    return value.toString();
  }

  static String _stringifyDataValue(
    dynamic value,
    EventValueFormatter formatter,
  ) {
    if (value == null) return 'null';
    if (value is List) {
      return '[${value.map((v) => _stringifyDataValue(v, formatter)).join(', ')}]';
    }
    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
      final body = entries
          .map(
            (entry) =>
                '${entry.key}: ${_stringifyDataValue(entry.value, formatter)}',
          )
          .join(', ');
      return '{$body}';
    }
    return formatter.format(value);
  }

  static String _stringifyRawValue(dynamic value) {
    if (value == null) return 'null';
    if (value is List) {
      return '[${value.map(_stringifyRawValue).join(', ')}]';
    }
    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
      final body = entries
          .map((entry) => '${entry.key}: ${_stringifyRawValue(entry.value)}')
          .join(', ');
      return '{$body}';
    }
    return _encodeValue(value).toString();
  }
}
