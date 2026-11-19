import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../constants/app_config.dart';
import '../../core/di/app_services.dart';
import '../../models/version_info.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/update_provider.dart';
import '../../utils/ui_utils.dart';
import '../../widgets/app_logo.dart';
import '../shell/update_dialog.dart';
import 'permissions_screen.dart';

/// Appearance, security, login and app information.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeProvider theme = context.watch<ThemeProvider>();
    final AuthProvider auth = context.watch<AuthProvider>();
    final AppServices services = context.read<AppServices>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          const _SectionTitle('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: SegmentedButton<ThemeMode>(
              segments: const <ButtonSegment<ThemeMode>>[
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_rounded),
                  label: Text('System'),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_rounded),
                  label: Text('Light'),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_rounded),
                  label: Text('Dark'),
                ),
              ],
              selected: <ThemeMode>{theme.mode},
              onSelectionChanged: (Set<ThemeMode> s) => theme.setMode(s.first),
            ),
          ),
          const _SectionTitle('Security'),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint_rounded),
            title: Text(auth.capability.label),
            subtitle: Text(
              auth.capability.isSupported
                  ? (auth.capability.isEnrolled
                      ? 'Require authentication when opening the app'
                      : 'Enrol a fingerprint or face in system settings first')
                  : 'Not supported on this device',
            ),
            value: auth.biometricEnabled,
            onChanged: auth.capability.isAvailable
                ? (bool v) async {
                    final bool ok = await auth.setBiometricEnabled(value: v);
                    if (!ok && context.mounted) {
                      UiUtils.showSnack(context, 'Authentication failed');
                    }
                  }
                : null,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.key_rounded),
            title: const Text('Remember login'),
            subtitle: const Text('Store your login encrypted on this device'),
            value: auth.rememberLogin,
            onChanged: (bool v) => auth.setRememberLogin(value: v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.login_rounded),
            title: const Text('Auto login'),
            subtitle: Text(auth.hasSavedCredentials
                ? 'Sign in automatically when your session expires'
                : 'Log in once with "Remember login" on to enable'),
            value: auth.autoLogin,
            onChanged: auth.rememberLogin ? (bool v) => auth.setAutoLogin(value: v) : null,
          ),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text('App permissions'),
            subtitle: const Text('Camera, microphone, location, notifications…'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const PermissionsScreen()),
            ),
          ),
          const _SectionTitle('Storage'),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Clear cache'),
            subtitle: const Text('Frees space; you stay logged in'),
            onTap: () async {
              await services.webSession.clearCache();
              if (context.mounted) UiUtils.showSnack(context, 'Cache cleared');
            },
          ),
          const _SectionTitle('About'),
          const _UpdateTile(),
          ListTile(
            leading: const Icon(Icons.star_outline_rounded),
            title: const Text('Rate the app'),
            onTap: services.launcher.openPlayStore,
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy policy'),
            onTap: () => services.launcher.openInAppBrowser(AppConfig.url(AppConfig.privacyPath)),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('App information'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: AppConfig.appName,
              applicationVersion: services.deviceInfo.fullVersion,
              applicationIcon: const AppLogo(size: 48),
              applicationLegalese: '© ${DateTime.now().year} ${AppConfig.appName}',
              children: <Widget>[
                const SizedBox(height: 12),
                Text('Device: ${services.deviceInfo.deviceName}'),
                Text('Android SDK: ${services.deviceInfo.sdkInt}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpdateTile extends StatelessWidget {
  const _UpdateTile();

  @override
  Widget build(BuildContext context) {
    final UpdateProvider updates = context.watch<UpdateProvider>();
    return ListTile(
      leading: const Icon(Icons.system_update_rounded),
      title: const Text('Check for updates'),
      subtitle: Text('Installed version ${updates.installedVersion}'),
      trailing: updates.isBusy
          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : null,
      onTap: () async {
        await updates.check();
        if (!context.mounted) return;
        if (updates.requirement == UpdateRequirement.optional) {
          updates.consumeOptionalPrompt();
          await UpdateDialog.show(context);
        } else if (updates.requirement == UpdateRequirement.none) {
          UiUtils.showSnack(context, 'You are using the latest version');
        }
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
        ),
      );
}
