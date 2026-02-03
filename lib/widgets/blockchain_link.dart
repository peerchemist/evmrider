import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// A clickable link widget for blockchain data (transactions, blocks, addresses).
/// 
/// Tap opens the link in an external browser.
/// Long-press or right-click copies the link to clipboard.
class BlockchainLink extends StatelessWidget {
  final String displayText;
  final String url;
  final VoidCallback? onCopied;

  const BlockchainLink({
    super.key,
    required this.displayText,
    required this.url,
    this.onCopied,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _openLink(context),
      onLongPress: () => _copyLink(context),
      onSecondaryTap: () => _copyLink(context),
      mouseCursor: SystemMouseCursors.click,
      child: Text(
        displayText,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Future<void> _openLink(BuildContext context) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $uri')),
      );
    }
  }

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: url));
    onCopied?.call();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied')),
    );
  }
}

/// A transaction hash link that opens in a block explorer.
class TransactionLink extends StatelessWidget {
  final String txHash;
  final String blockExplorerUrl;

  const TransactionLink({
    super.key,
    required this.txHash,
    this.blockExplorerUrl = 'https://etherscan.io',
  });

  @override
  Widget build(BuildContext context) {
    final cleanUrl = blockExplorerUrl.replaceAll(RegExp(r'/+$'), '');
    final link = '$cleanUrl/tx/$txHash';
    return BlockchainLink(
      displayText: txHash,
      url: link,
    );
  }
}

/// A block number link that opens in a block explorer.
class BlockLink extends StatelessWidget {
  final int blockNumber;
  final String blockExplorerUrl;

  const BlockLink({
    super.key,
    required this.blockNumber,
    this.blockExplorerUrl = 'https://etherscan.io',
  });

  @override
  Widget build(BuildContext context) {
    final cleanUrl = blockExplorerUrl.replaceAll(RegExp(r'/+$'), '');
    final link = '$cleanUrl/block/$blockNumber';
    return BlockchainLink(
      displayText: blockNumber.toString(),
      url: link,
    );
  }
}
