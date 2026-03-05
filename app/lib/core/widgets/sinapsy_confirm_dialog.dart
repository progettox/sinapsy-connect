import 'dart:ui';

import 'package:flutter/cupertino.dart';

Future<bool> showSinapsyConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String cancelLabel = 'Annulla',
  String confirmLabel = 'Conferma',
  bool destructive = false,
  IconData? icon,
}) async {
  final result = await showCupertinoDialog<bool>(
    context: context,
    builder: (context) {
      final theme = CupertinoTheme.of(context);
      final confirmColor = destructive
          ? const Color(0xFFE28888)
          : const Color(0xFFA855F7);

      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: CupertinoAlertDialog(
            title: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: confirmColor),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.navTitleTextStyle.copyWith(
                      color: const Color(0xFFF5F5F7),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            content: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                message,
                style: theme.textTheme.textStyle.copyWith(
                  color: const Color(0xFFE6E6EB),
                  height: 1.35,
                ),
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelLabel),
              ),
              CupertinoDialogAction(
                isDestructiveAction: destructive,
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ),
      );
    },
  );

  return result == true;
}
