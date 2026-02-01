import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

bool shouldCopyTextOnThisPlatform() {
  if (kIsWeb) return true;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return false;
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      return true;
  }
}

void maybeHapticFeedback() {
  if (kIsWeb) return;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      HapticFeedback.selectionClick();
      break;
    default:
      break;
  }
}

Future<void> shareOrCopyText({
  required BuildContext context,
  required String text,
  String? subject,
  String copiedToast = 'Copied to clipboard',
}) async {
  if (text.trim().isEmpty) return;
  if (shouldCopyTextOnThisPlatform()) {
    maybeHapticFeedback();
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(copiedToast)));
    return;
  }
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null
      ? const Rect.fromLTWH(0, 0, 0, 0)
      : box.localToGlobal(Offset.zero) & box.size;
  await Share.share(
    text,
    subject: subject,
    sharePositionOrigin: origin,
  );
}
