import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_strings.dart';
import '../../providers/update_provider.dart';
import '../../widgets/status_illustration.dart';

/// Blocking screen shown when the installed version is below the minimum
/// supported version. The user cannot continue without updating.
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final UpdateProvider updates = context.watch<UpdateProvider>();
    final ThemeData theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) SystemNavigator.pop();
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: <Widget>[
                  const StatusIllustration(icon: Icons.system_update_rounded),
                  const SizedBox(height: 28),
                  Text(
                    AppStrings.forceUpdateTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    updates.message ?? AppStrings.forceUpdateMessage,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Installed ${updates.installedVersion}'
                    '${updates.versionInfo == null ? '' : ' · Required ${updates.versionInfo!.minSupportedVersion}+'}',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.primary),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: updates.isBusy ? null : updates.startForcedUpdate,
                    icon: const Icon(Icons.shop_rounded),
                    label: const Text(AppStrings.updateNow),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: updates.isBusy ? null : updates.check,
                    child: const Text('I have updated – check again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
