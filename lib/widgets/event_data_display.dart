import 'package:flutter/material.dart';
import 'package:evmrider/utils/event_value_formatter.dart';

/// Displays event data as a formatted key-value list.
class EventDataDisplay extends StatelessWidget {
  final Map<String, dynamic> data;
  final int tokenDecimals;

  const EventDataDisplay({
    super.key,
    required this.data,
    this.tokenDecimals = 18,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SelectableText(
        '{}',
        style: TextStyle(fontFamily: 'monospace'),
      );
    }

    final formatter = EventValueFormatter(tokenDecimals: tokenDecimals);
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
                    formatter.format(entry.value),
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
