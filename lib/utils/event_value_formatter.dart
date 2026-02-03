import 'package:wallet/wallet.dart' as wallet;
import 'package:evmrider/utils/utils.dart';

/// Formats event values for display, handling addresses, BigInts, lists, etc.
class EventValueFormatter {
  final int tokenDecimals;

  const EventValueFormatter({this.tokenDecimals = 18});

  /// Format any event value for display.
  String format(dynamic value) {
    if (value is List) {
      return '[${value.map(format).join(', ')}]';
    }
    final address = _formatAddressValue(value);
    if (address != null) {
      return address;
    }
    if (value is String) {
      final normalized = value.trim();
      if (normalized.startsWith('0x') || normalized.startsWith('0X')) {
        return normalized;
      }
    }
    final bigInt = _toBigInt(value);
    if (bigInt != null) {
      return formatBigIntWithDecimals(bigInt, tokenDecimals);
    }
    return value.toString();
  }

  /// Try to extract a hex address from various value types.
  String? _formatAddressValue(dynamic value) {
    if (value is wallet.EthereumAddress) {
      return value.with0x.toLowerCase();
    }
    if (value is String) {
      return normalizeHexAddress(value);
    }
    final dynamic dyn = value;
    try {
      final hex = dyn.hex;
      if (hex is String && (hex.startsWith('0x') || hex.startsWith('0X'))) {
        return hex.toLowerCase();
      }
    } catch (_) {}
    try {
      final hexEip55 = dyn.hexEip55;
      if (hexEip55 is String &&
          (hexEip55.startsWith('0x') || hexEip55.startsWith('0X'))) {
        return hexEip55.toLowerCase();
      }
    } catch (_) {}
    return null;
  }

  /// Try to convert a value to BigInt.
  BigInt? _toBigInt(dynamic value) {
    if (value is BigInt) return value;
    if (value is int) return BigInt.from(value);
    if (value is String) {
      final normalized = value.trim();
      if (normalized.startsWith('0x') || normalized.startsWith('0X')) {
        return null;
      }
      if (RegExp(r'^-?\d+$').hasMatch(normalized)) {
        return BigInt.tryParse(normalized);
      }
    }
    return null;
  }

  /// Format a BigInt with decimal places.
  static String formatBigIntWithDecimals(BigInt value, int decimals) {
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

/// Format event data map for sharing as text.
String formatEventDataForShare(
  String eventName,
  Map<String, dynamic> data, {
  int tokenDecimals = 18,
}) {
  final formatter = EventValueFormatter(tokenDecimals: tokenDecimals);
  final header = 'Event: $eventName';
  if (data.isEmpty) return '$header\n{}';
  final entries = data.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  final body = entries
      .map((entry) => '${entry.key}: ${formatter.format(entry.value)}')
      .join('\n');
  return '$header\n$body';
}
