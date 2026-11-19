import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../core/di/app_services.dart';
import '../../services/permission_service.dart';

/// Lists every runtime permission with its status and a request button.
///
/// Shown once after the first launch ([onContinue] set) and later from
/// Settings → App permissions.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key, this.onContinue});

  final VoidCallback? onContinue;

  bool get isOnboarding => onContinue != null;

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> with WidgetsBindingObserver {
  late final PermissionService _permissions = context.read<AppServices>().permissions;
  final Map<AppPermission, AppPermissionState> _states = <AppPermission, AppPermissionState>{};
  bool _requestingAll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from system settings.
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    for (final AppPermission p in AppPermission.values) {
      _states[p] = await _permissions.status(p);
    }
    if (mounted) setState(() {});
  }

  Future<void> _request(AppPermission permission) async {
    if (_states[permission] == AppPermissionState.permanentlyDenied) {
      await _permissions.openSettings();
      return;
    }
    _states[permission] = await _permissions.request(permission);
    if (mounted) setState(() {});
  }

  Future<void> _requestAll() async {
    setState(() => _requestingAll = true);
    await _permissions.requestAll(AppPermission.values);
    await _refresh();
    if (mounted) setState(() => _requestingAll = false);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: widget.isOnboarding ? null : AppBar(title: const Text('App permissions')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            if (widget.isOnboarding) ...<Widget>[
              const SizedBox(height: 16),
              const Icon(Icons.verified_user_rounded, size: 64, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                'Allow access',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'These permissions let the app scan codes, upload photos, send you '
                'notices and more. You can change them anytime in Settings.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
            ],
            for (final AppPermission p in AppPermission.values)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Icon(p.icon, color: AppColors.primary),
                  ),
                  title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(p.rationale),
                  trailing: _StatusAction(
                    state: _states[p],
                    onRequest: () => _request(p),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            if (widget.isOnboarding) ...<Widget>[
              FilledButton(
                onPressed: _requestingAll ? null : () async {
                  await _requestAll();
                  widget.onContinue!();
                },
                child: const Text('Allow all & continue'),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: widget.onContinue, child: const Text('Not now')),
            ] else
              OutlinedButton.icon(
                onPressed: _permissions.openSettings,
                icon: const Icon(Icons.settings_rounded),
                label: const Text('Open system settings'),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusAction extends StatelessWidget {
  const _StatusAction({required this.state, required this.onRequest});

  final AppPermissionState? state;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      null => const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      AppPermissionState.granted => const Icon(Icons.check_circle_rounded, color: AppColors.success),
      AppPermissionState.notRequired => const Tooltip(
          message: 'Not required on this Android version',
          child: Icon(Icons.check_circle_outline_rounded, color: AppColors.success),
        ),
      AppPermissionState.denied => TextButton(onPressed: onRequest, child: const Text('Allow')),
      AppPermissionState.permanentlyDenied =>
        TextButton(onPressed: onRequest, child: const Text('Settings')),
    };
  }
}
