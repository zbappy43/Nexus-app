import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../constants/app_strings.dart';
import '../../providers/update_provider.dart';

/// Optional update prompt ("Update now" / "Later").
abstract final class UpdateDialog {
  static Future<void> show(BuildContext context) async {
    final UpdateProvider updates = context.read<UpdateProvider>();
    final bool? accepted = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        icon: const Icon(Icons.system_update_rounded, size: 36),
        title: const Text(AppStrings.updateTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(updates.message ?? AppStrings.updateMessage),
            const SizedBox(height: 12),
            Text(
              'Installed: ${updates.installedVersion}'
              '${updates.latestVersion == null ? '' : '\nLatest: ${updates.latestVersion}'}',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(AppStrings.later),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(AppStrings.updateNow),
          ),
        ],
      ),
    );
    if (accepted ?? false) {
      await updates.startOptionalUpdate();
    } else {
      await updates.skipOptionalUpdate();
    }
  }
}
