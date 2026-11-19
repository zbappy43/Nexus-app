import 'package:material_ui/material_ui.dart';

import '../constants/app_config.dart';
import '../constants/app_strings.dart';

/// The four native bottom-navigation tabs; each hosts its own WebView.
enum AppTab {
  home(AppStrings.home, Icons.home_outlined, Icons.home_rounded, AppConfig.homePath),
  team(AppStrings.team, Icons.groups_outlined, Icons.groups_rounded, AppConfig.teamPath),
  wallet(AppStrings.wallet, Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet_rounded, AppConfig.walletPath),
  profile(AppStrings.profile, Icons.person_outline_rounded, Icons.person_rounded,
      AppConfig.profilePath);

  const AppTab(this.label, this.icon, this.selectedIcon, this.path);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;

  String get url => AppConfig.url(path);
}
