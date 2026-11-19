import 'package:material_ui/material_ui.dart';

import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import 'status_illustration.dart';

/// Full-page status message with illustration and a primary action.
class StatusView extends StatelessWidget {
  const StatusView({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    super.key,
    this.busy = false,
    this.color = AppColors.primary,
    this.details,
    this.secondaryLabel,
    this.onSecondary,
  });

  /// Shown when the device has no internet connection.
  factory StatusView.offline({required VoidCallback onRetry, bool busy = false, Key? key}) =>
      StatusView(
        key: key,
        icon: Icons.wifi_off_rounded,
        title: AppStrings.offlineTitle,
        message: AppStrings.offlineMessage,
        actionLabel: AppStrings.retry,
        onAction: onRetry,
        busy: busy,
      );

  /// Shown when a page failed to load.
  factory StatusView.error({
    required VoidCallback onReload,
    String? details,
    VoidCallback? onHome,
    Key? key,
  }) =>
      StatusView(
        key: key,
        icon: Icons.cloud_off_rounded,
        title: AppStrings.errorTitle,
        message: AppStrings.errorMessage,
        details: details,
        actionLabel: AppStrings.reload,
        onAction: onReload,
        color: AppColors.warning,
        secondaryLabel: onHome == null ? null : AppStrings.home,
        onSecondary: onHome,
      );

  /// Shown when certificate pinning rejected the server.
  factory StatusView.insecure({required VoidCallback onRetry, Key? key}) => StatusView(
        key: key,
        icon: Icons.gpp_bad_rounded,
        title: AppStrings.securityErrorTitle,
        message: AppStrings.securityErrorMessage,
        actionLabel: AppStrings.retry,
        onAction: onRetry,
        color: AppColors.error,
      );

  final IconData icon;
  final String title;
  final String message;
  final String? details;
  final String actionLabel;
  final VoidCallback onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool busy;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  StatusIllustration(icon: icon, color: color),
                  const SizedBox(height: 28),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  if (details != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      details!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: busy ? null : onAction,
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(actionLabel),
                  ),
                  if (secondaryLabel != null && onSecondary != null) ...<Widget>[
                    const SizedBox(height: 12),
                    TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
