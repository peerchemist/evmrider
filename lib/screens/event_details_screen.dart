import 'package:flutter/material.dart';
import 'package:evmrider/models/event.dart';
import 'package:evmrider/models/config.dart';
import 'package:evmrider/services/eventlistener.dart';
import 'package:evmrider/utils/share_event.dart';
import 'package:evmrider/utils/event_value_formatter.dart';
import 'package:evmrider/widgets/event_data_display.dart';
import 'package:evmrider/widgets/blockchain_link.dart';

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
  late int _resolvedTokenDecimals;

  String get _blockExplorerUrl =>
      widget.config?.blockExplorerUrl ?? 'https://etherscan.io';

  @override
  void initState() {
    super.initState();
    _resolvedTokenDecimals = widget.tokenDecimals;
    _resolveTokenDecimalsFromConfig();
  }

  Future<void> _resolveTokenDecimalsFromConfig() async {
    final config = widget.config;
    if (config == null || !config.isValid()) return;

    EthereumEventService? service;
    try {
      service = EthereumEventService(config);
      final decimals = await service.getTokenDecimals();
      if (!mounted) return;
      setState(() => _resolvedTokenDecimals = decimals < 0 ? 0 : decimals);
    } catch (_) {
      // Keep the existing fallback when lookup fails.
    } finally {
      service?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event.eventName),
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
                txHash: widget.event.transactionHash,
                blockExplorerUrl: _blockExplorerUrl,
              ),
              const SizedBox(height: 16),
              const Text(
                'Block Number:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              BlockLink(
                blockNumber: widget.event.blockNumber,
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
                  data: widget.event.data,
                  tokenDecimals: _resolvedTokenDecimals,
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
      widget.event.eventName,
      widget.event.data,
      tokenDecimals: _resolvedTokenDecimals,
    );
    await shareOrCopyText(
      context: context,
      text: text,
      subject: 'Event data',
      copiedToast: 'Event data copied',
    );
  }
}
