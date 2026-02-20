import 'dart:convert';
import 'dart:typed_data';

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

  String toShareString() {
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
      lines.add('${entry.key}: ${_stringifyValue(entry.value)}');
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

  static String _stringifyValue(dynamic value) {
    if (value == null) return 'null';
    if (value is num || value is bool || value is String) return value.toString();
    if (value is BigInt) return value.toString();
    if (value is Uint8List) return value.toList().toString();
    if (value is List) {
      return '[${value.map(_stringifyValue).join(', ')}]';
    }
    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
      final body = entries
          .map((entry) => '${entry.key}: ${_stringifyValue(entry.value)}')
          .join(', ');
      return '{$body}';
    }
    return value.toString();
  }
}
