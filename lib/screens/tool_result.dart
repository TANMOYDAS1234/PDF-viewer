import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_theme.dart';
import 'viewer_screen.dart';

/// Success dialog shown after a PDF tool produces a file, offering Open / Share.
Future<void> showToolResult(BuildContext context, String path) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.check_circle_rounded,
          color: AppColors.success, size: 44),
      title: const Text('Done'),
      content: Text('Saved to:\n$path', textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton.icon(
          onPressed: () {
            Navigator.pop(ctx);
            Share.shareXFiles([XFile(path)]);
          },
          icon: const Icon(Icons.share_rounded, size: 18),
          label: const Text('Share'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(ctx);
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ViewerScreen(filePath: path)),
            );
          },
          icon: const Icon(Icons.visibility_rounded, size: 18),
          label: const Text('Open'),
        ),
      ],
    ),
  );
}
