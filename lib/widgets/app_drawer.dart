import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../constants/app_config.dart';
import '../constants/app_strings.dart';
import '../core/di/app_services.dart';
import '../models/nav_destination.dart';
import '../providers/navigation_provider.dart';
import 'app_logo.dart';

/// Actions the drawer delegates to the shell.
class DrawerActions {
  const DrawerActions({
    required this.onDownloads,
    required this.onNotifications,
    required this.onScanQr,
    required this.onPhotoTools,
    required this.onSettings,
    required this.onLogout,
  });

  final VoidCallback onDownloads;
  final VoidCallback onNotifications;
  final VoidCallback onScanQr;
  final VoidCallback onPhotoTools;
  final VoidCallback onSettings;
  final VoidCallback onLogout;
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({required this.actions, super.key});

  final DrawerActions actions;

  @override
  Widget build(BuildContext context) {
    final NavigationProvider navigation = context.watch<NavigationProvider>();
    final String version = context.read<AppServices>().deviceInfo.fullVersion;

    void close() => Navigator.of(context).pop();

    Widget tabItem(AppTab tab) => _DrawerItem(
      icon: tab.icon,
      label: tab.label,
      selected: navigation.current == tab,
      onTap: () {
        close();
        navigation.select(tab);
      },
    );

    Widget pathItem(IconData icon, String label, String path) => _DrawerItem(
      icon: icon,
      label: label,
      onTap: () {
        close();
        navigation.openPath(path);
      },
    );

    Widget actionItem(IconData icon, String label, VoidCallback action, {Color? color}) =>
        _DrawerItem(
          icon: icon,
          label: label,
          color: color,
          onTap: () {
            close();
            action();
          },
        );

    return Drawer(
      child: Column(
        children: <Widget>[
          _Header(version: version),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: <Widget>[
                tabItem(AppTab.home),
                tabItem(AppTab.profile),
                tabItem(AppTab.wallet),
                tabItem(AppTab.team),
                pathItem(Icons.school_outlined, AppStrings.training, AppConfig.trainingPath),
                pathItem(Icons.campaign_outlined, AppStrings.notice, AppConfig.noticePath),
                pathItem(Icons.support_agent_rounded, AppStrings.support, AppConfig.supportPath),
                actionItem(Icons.download_rounded, AppStrings.downloads, actions.onDownloads),
                pathItem(Icons.contact_phone_outlined, AppStrings.contact, AppConfig.contactPath),
                pathItem(Icons.info_outline_rounded, AppStrings.aboutUs, AppConfig.aboutPath),
                pathItem(
                  Icons.privacy_tip_outlined,
                  AppStrings.privacyPolicy,
                  AppConfig.privacyPath,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Divider(),
                ),
                actionItem(
                  Icons.notifications_none_rounded,
                  AppStrings.notifications,
                  actions.onNotifications,
                ),
                actionItem(Icons.qr_code_scanner_rounded, AppStrings.scanQr, actions.onScanQr),
                actionItem(
                  Icons.photo_camera_back_outlined,
                  AppStrings.imageTools,
                  actions.onPhotoTools,
                ),
                actionItem(Icons.settings_outlined, AppStrings.settings, actions.onSettings),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Divider(),
                ),
                actionItem(
                  Icons.logout_rounded,
                  AppStrings.logout,
                  actions.onLogout,
                  color: AppColors.error,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, MediaQuery.paddingOf(context).top + 24, 24, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.primary, AppColors.primaryDark],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.accent, width: 2),
            ),
            child: const AppLogo(size: 56),
          ),
          const SizedBox(height: 16),
          Text(
            AppConfig.appName,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Version $version',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.accent),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        leading: Icon(icon, color: color ?? (selected ? scheme.primary : null)),
        title: Text(
          label,
          style: TextStyle(
            color: color ?? (selected ? scheme.primary : null),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        selected: selected,
        selectedTileColor: AppColors.accent.withValues(alpha: 0.18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        onTap: onTap,
      ),
    );
  }
}
