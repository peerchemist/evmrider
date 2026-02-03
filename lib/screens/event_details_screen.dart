import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:evmrider/models/event.dart';
import 'package:evmrider/utils/utils.dart';
import 'package:evmrider/utils/share_event.dart';
import 'package:evmrider/utils/block_explorer.dart';
import 'package:evmrider/models/config.dart';
import 'package:wallet/wallet.dart' as wallet;

class EventDetailsScreen extends StatefulWidget {
  final Event event;
  final int tokenDecimals;
  final EthereumConfig? config;

  const EventDetailsScreen({
    super.key,
    required this.event,
    this.tokenDecimals = 18,
    this.config,
  });

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  late final BlockExplorer _blockExplorer;

  @override
  void initState() {
    super.initState();
    _blockExplorer = BlockExplorer(
      widget.config?.blockExplorerUrl ?? 'https://etherscan.io',
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    return Scaffold(
      appBar: AppBar(
        title: Text(event.eventName),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareEventData(event),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transaction Hash:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            _buildTransactionLink(event.transactionHash),
            const SizedBox(height: 16),
            const Text(
              'Block Number:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            _buildBlockLink(event.blockNumber),
            const SizedBox(height: 16),
            const Text(
              'Event Data:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: _buildEventData(event.data),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockLink(int blockNumber) {
    final theme = Theme.of(context);
    final link = _blockExplorer.blockLink(blockNumber);
    
    return InkWell(
      onTap: () => _openLink(link),
      onLongPress: () => _copyLink(link),
      onSecondaryTap: () => _copyLink(link),
      mouseCursor: SystemMouseCursors.click,
      child: Text(
        blockNumber.toString(),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildTransactionLink(String txHash) {
    final theme = Theme.of(context);
    final link = _blockExplorer.transactionLink(txHash);
    return InkWell(
      onTap: () => _openLink(link),
      onLongPress: () => _copyLink(link),
      onSecondaryTap: () => _copyLink(link),
      mouseCursor: SystemMouseCursors.click,
      child: Text(
        txHash,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open $uri')));
    }
  }

  Future<void> _copyLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link copied')));
  }

  Future<void> _shareEventData(Event event) async {
    final text = _formatEventDataForShare(event);
    await shareOrCopyText(
      context: context,
      text: text,
      subject: 'Event data',
      copiedToast: 'Event data copied',
    );
  }

  String _formatEventDataForShare(Event event) {
    final data = event.data;
    final header = 'Event: ${event.eventName}';
    if (data.isEmpty) return '$header\n{}';
    final entries = data.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final body = entries
        .map((entry) => '${entry.key}: ${_formatEventValue(entry.value)}')
        .join('\n');
    return '$header\n$body';
  }

  Widget _buildEventData(Map<String, dynamic> data) {
    if (data.isEmpty) {
      return const SelectableText(
        '{}',
        style: TextStyle(fontFamily: 'monospace'),
      );
    }

    final entries = data.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    _formatEventValue(entry.value),
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  String _formatEventValue(dynamic value) {
    if (value is List) {
      return '[${value.map(_formatEventValue).join(', ')}]';
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
      return _formatBigIntWithDecimals(bigInt, widget.tokenDecimals);
    }
    return value.toString();
  }

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

  String _formatBigIntWithDecimals(BigInt value, int decimals) {
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

  String _buildDecimalString(bool isNegative, String intPart, String fracPart) {
    final sign = isNegative ? '-' : '';
    if (fracPart.isEmpty) return '$sign$intPart';
    return '$sign$intPart.$fracPart';
  }

  String _trimTrailingZeros(String value) {
    var end = value.length;
    while (end > 0 && value[end - 1] == '0') {
      end--;
    }
    return value.substring(0, end);
  }
}
