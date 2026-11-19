import 'package:material_ui/material_ui.dart';

import '../constants/app_strings.dart';

/// Shared snackbar / dialog helpers.
abstract final class UiUtils {
  static void showSnack(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration,
          action: actionLabel == null || onAction == null
              ? null
              : SnackBarAction(label: actionLabel, onPressed: onAction),
        ),
      );
  }

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = AppStrings.cancel,
    IconData icon = Icons.help_outline_rounded,
    bool destructive = false,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        final ColorScheme scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          icon: Icon(icon, color: destructive ? scheme.error : scheme.primary, size: 32),
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(cancelLabel),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                      minimumSize: const Size(96, 44),
                    )
                  : FilledButton.styleFrom(minimumSize: const Size(96, 44)),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}
