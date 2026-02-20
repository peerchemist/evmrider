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

  String toShareString({int tokenDecimals = 18}) {
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
      lines.add(
        '${entry.key}: ${_stringifyValue(entry.value, tokenDecimals: tokenDecimals)}',
      );
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

  static String _stringifyValue(dynamic value, {required int tokenDecimals}) {
    if (value == null) return 'null';
    if (value is bool) return value.toString();
    if (value is String) {
      final normalized = value.trim();
      if (normalized.startsWith('0x') || normalized.startsWith('0X')) {
        return normalized;
      }
      final parsed = _tryParseBigInt(normalized);
      if (parsed != null) {
        return _formatBigIntWithDecimals(parsed, tokenDecimals);
      }
      return value;
    }
    if (value is BigInt) {
      return _formatBigIntWithDecimals(value, tokenDecimals);
    }
    if (value is int) {
      return _formatBigIntWithDecimals(BigInt.from(value), tokenDecimals);
    }
    if (value is num) return value.toString();
    if (value is Uint8List) return value.toList().toString();
    if (value is List) {
      return '[${value.map((v) => _stringifyValue(v, tokenDecimals: tokenDecimals)).join(', ')}]';
    }
    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
      final body = entries
          .map(
            (entry) =>
                '${entry.key}: ${_stringifyValue(entry.value, tokenDecimals: tokenDecimals)}',
          )
          .join(', ');
      return '{$body}';
    }
    return value.toString();
  }

  static BigInt? _tryParseBigInt(String value) {
    if (!RegExp(r'^-?\d+$').hasMatch(value)) return null;
    return BigInt.tryParse(value);
  }

  static String _formatBigIntWithDecimals(BigInt value, int decimals) {
    if (decimals <= 0) return value.toString();
    final isNegative = value.isNegative;
    final raw = value.abs().toString();

    if (raw.length <= decimals) {
      final padded = raw.padLeft(decimals + 1, '0');
      final intPart = padded.substring(0, padded.length - decimals);
      final fracPart = _trimTrailingZeros(
        padded.substring(padded.length - decimals),
      );
      return _buildDecimalString(isNegative, intPart, fracPart);
    }

    final intPart = raw.substring(0, raw.length - decimals);
    final fracPart = _trimTrailingZeros(raw.substring(raw.length - decimals));
    return _buildDecimalString(isNegative, intPart, fracPart);
  }

  static String _buildDecimalString(
    bool isNegative,
    String intPart,
    String fracPart,
  ) {
    final sign = isNegative ? '-' : '';
    if (fracPart.isEmpty) return '$sign$intPart';
    return '$sign$intPart.$fracPart';
  }

  static String _trimTrailingZeros(String value) {
    var end = value.length;
    while (end > 0 && value[end - 1] == '0') {
      end--;
    }
    return value.substring(0, end);
  }
}
