import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ExternalLink extends StatelessWidget {
  final String label;
  final String url;
  final TextStyle? style;
  final bool underline;

  const ExternalLink({
    super.key,
    required this.label,
    required this.url,
    this.style,
    this.underline = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _open(context),
      mouseCursor: SystemMouseCursors.click,
      child: Text(
        label,
        style: style ??
            theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              decoration:
                  underline ? TextDecoration.underline : TextDecoration.none,
            ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $uri')),
      );
    }
  }
}
