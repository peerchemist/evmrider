import 'package:flutter/material.dart';
import 'package:evmrider/models/event.dart';
import 'package:evmrider/models/config.dart';
import 'package:evmrider/utils/share_event.dart';
import 'package:evmrider/utils/event_value_formatter.dart';
import 'package:evmrider/widgets/event_data_display.dart';
import 'package:evmrider/widgets/blockchain_link.dart';

class EventDetailsScreen extends StatelessWidget {
  final Event event;
  final int tokenDecimals;
  final EthereumConfig? config;

  const EventDetailsScreen({
    super.key,
    required this.event,
    this.tokenDecimals = 18,
    this.config,
  });

  String get _blockExplorerUrl =>
      config?.blockExplorerUrl ?? 'https://etherscan.io';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(event.eventName),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareEventData(context),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Transaction Hash:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TransactionLink(
                txHash: event.transactionHash,
                blockExplorerUrl: _blockExplorerUrl,
              ),
              const SizedBox(height: 16),
              const Text(
                'Block Number:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              BlockLink(
                blockNumber: event.blockNumber,
                blockExplorerUrl: _blockExplorerUrl,
              ),
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
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: EventDataDisplay(
                  data: event.data,
                  tokenDecimals: tokenDecimals,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareEventData(BuildContext context) async {
    final text = formatEventDataForShare(
      event.eventName,
      event.data,
      tokenDecimals: tokenDecimals,
    );
    await shareOrCopyText(
      context: context,
      text: text,
      subject: 'Event data',
      copiedToast: 'Event data copied',
    );
  }
}
