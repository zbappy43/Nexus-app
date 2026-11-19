import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../constants/app_config.dart';
import '../../constants/app_strings.dart';
import '../../core/di/app_services.dart';
import '../../models/download_item.dart';
import '../../models/nav_destination.dart';
import '../../providers/auth_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/update_provider.dart';
import '../../utils/file_utils.dart';
import '../../utils/ui_utils.dart';
import '../../utils/url_utils.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/nexus_web_view.dart';
import '../downloads/downloads_screen.dart';
import '../media/image_tools_screen.dart';
import '../notifications/notifications_screen.dart';
import '../pdf/pdf_viewer_screen.dart';
import '../scanner/qr_scanner_screen.dart';
import '../settings/settings_screen.dart';
import 'update_dialog.dart';

/// Main screen: app bar, drawer, native bottom navigation and one WebView per tab.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialUrl});

  /// Deep link / notification URL that launched the app.
  final String? initialUrl;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<StreamSubscription<Object?>> _subscriptions = <StreamSubscription<Object?>>[];
  final Map<AppTab, String> _titles = <AppTab, String>{};
  DateTime? _lastBackPress;
  bool _flexibleUpdateNotified = false;

  late final AppServices _services = context.read<AppServices>();
  late final NavigationProvider _navigation = context.read<NavigationProvider>();
  late final UpdateProvider _updates = context.read<UpdateProvider>();
  late final AuthProvider _auth = context.read<AuthProvider>();
  late bool _wasLocked = _auth.isLocked;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscriptions
      ..add(_services.push.onOpenUrl.listen(_openIncomingUrl))
      ..add(_services.oneSignal.onOpenUrl.listen(_openIncomingUrl))
      ..add(_services.localNotifications.onTapUrl.listen(_openIncomingUrl))
      ..add(_services.deepLinks.links.listen(_openIncomingUrl))
      ..add(context.read<DownloadProvider>().onCompleted.listen(_onDownloadCompleted));
    _updates.addListener(_onUpdateStateChanged);
    _auth.addListener(_onAuthChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final String? initial = widget.initialUrl;
      if (initial != null) _openIncomingUrl(initial);
      unawaited(_maybeShowOptionalUpdate());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updates.removeListener(_onUpdateStateChanged);
    _auth.removeListener(_onAuthChanged);
    for (final StreamSubscription<Object?> s in _subscriptions) {
      unawaited(s.cancel());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _auth.onAppBackgrounded();
      case AppLifecycleState.resumed:
        _auth.onAppResumed();
        unawaited(context.read<NotificationProvider>().refresh());
        unawaited(context.read<DownloadProvider>().refresh());
        unawaited(_services.connectivity.refresh());
      case AppLifecycleState.detached ||
            AppLifecycleState.inactive ||
            AppLifecycleState.hidden:
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Incoming links (push notifications, deep links)
  // ---------------------------------------------------------------------------
  void _openIncomingUrl(String raw) {
    final String url = raw.startsWith('/') ? AppConfig.url(raw) : raw;
    final String? resolved = UrlUtils.resolveDeepLink(url);
    if (resolved != null) {
      Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
      unawaited(_navigation.openUrl(resolved));
    } else {
      unawaited(_services.launcher.openExternal(url));
    }
  }

  /// Auto login is suspended while the biometric lock is shown; once the user
  /// unlocks, retry it if the current tab is sitting on the login page.
  void _onAuthChanged() {
    final bool locked = _auth.isLocked;
    if (_wasLocked && !locked) unawaited(_reloadIfOnLoginPage());
    _wasLocked = locked;
  }

  Future<void> _reloadIfOnLoginPage() async {
    final WebTabHandle? handle = _navigation.currentHandle;
    final String? url = await handle?.currentUrl();
    if (url == null) return;
    final String loginPath = Uri.parse(AppConfig.url(AppConfig.loginPath)).path;
    if ((Uri.tryParse(url)?.path ?? '').startsWith(loginPath)) await handle?.reload();
  }

  // ---------------------------------------------------------------------------
  // Updates & downloads feedback
  // ---------------------------------------------------------------------------
  Future<void> _maybeShowOptionalUpdate() async {
    if (!mounted || !_updates.consumeOptionalPrompt()) return;
    await UpdateDialog.show(context);
  }

  void _onUpdateStateChanged() {
    if (_updates.flexibleUpdateDownloaded && !_flexibleUpdateNotified && mounted) {
      _flexibleUpdateNotified = true;
      UiUtils.showSnack(
        context,
        'Update downloaded',
        actionLabel: 'Restart',
        onAction: _updates.installDownloadedUpdate,
        duration: const Duration(days: 1),
      );
    }
  }

  void _onDownloadCompleted(DownloadItem item) {
    if (!mounted) return;
    UiUtils.showSnack(
      context,
      'Downloaded ${item.fileName}',
      actionLabel: 'Open',
      onAction: () => _openDownloadedFile(item.filePath),
      duration: const Duration(seconds: 6),
    );
  }

  Future<void> _openDownloadedFile(String path) async {
    if (FileUtils.isPdf(path)) {
      await Navigator.of(context).push<void>(PdfViewerScreen.route(filePath: path));
      return;
    }
    final bool opened = await _services.downloads.openWithSystem(path);
    if (!opened && mounted) UiUtils.showSnack(context, 'No app installed to open this file');
  }

  // ---------------------------------------------------------------------------
  // App bar actions
  // ---------------------------------------------------------------------------
  Future<void> _refresh() async {
    await HapticFeedback.selectionClick();
    await _navigation.currentHandle?.reload();
  }

  Future<void> _openShareSheet() async {
    final WebTabHandle? handle = _navigation.currentHandle;
    final String url = await handle?.currentUrl() ?? AppConfig.baseUrl;
    final String? title = await handle?.currentTitle();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('Share this page'),
              subtitle: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.of(ctx).pop();
                unawaited(_services.share.sharePage(url: url, title: title));
              },
            ),
            ListTile(
              leading: const Icon(Icons.card_giftcard_rounded),
              title: const Text('Share referral link'),
              subtitle: Text(
                UrlUtils.referralLink(_services.settings.referralCode),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                unawaited(_services.share.shareReferral(_services.settings.referralCode));
              },
            ),
            ListTile(
              leading: const Icon(Icons.shop_rounded),
              title: const Text('Share the app'),
              subtitle: const Text('Google Play link'),
              onTap: () {
                Navigator.of(ctx).pop();
                unawaited(_services.share.shareApp());
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _push(Widget screen) =>
      unawaited(Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => screen)));

  Future<void> _logout() async {
    final bool confirmed = await UiUtils.confirm(
      context,
      title: AppStrings.logoutTitle,
      message: AppStrings.logoutMessage,
      confirmLabel: AppStrings.logout,
      icon: Icons.logout_rounded,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await context.read<AuthProvider>().logout();
    await _navigation.openPath(AppConfig.loginPath);
    if (mounted) UiUtils.showSnack(context, 'You have been logged out');
  }

  // ---------------------------------------------------------------------------
  // Back handling: drawer → WebView history → Home tab → double back to exit
  // ---------------------------------------------------------------------------
  Future<void> _onBack() async {
    if (_auth.isLocked) {
      await SystemNavigator.pop();
      return;
    }
    final ScaffoldState? scaffold = _scaffoldKey.currentState;
    if (scaffold != null && scaffold.isDrawerOpen) {
      scaffold.closeDrawer();
      return;
    }
    if (await _navigation.handleBack()) return;
    final DateTime now = DateTime.now();
    final DateTime? last = _lastBackPress;
    if (last != null && now.difference(last) <= AppConfig.exitBackPressWindow) {
      await SystemNavigator.pop();
      return;
    }
    _lastBackPress = now;
    if (mounted) {
      UiUtils.showSnack(context, AppStrings.pressBackAgain, duration: AppConfig.exitBackPressWindow);
    }
  }

  @override
  Widget build(BuildContext context) {
    final NavigationProvider navigation = context.watch<NavigationProvider>();
    final int unread = context.select<NotificationProvider, int>((NotificationProvider p) => p.unreadCount);
    final AppTab current = navigation.current;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) unawaited(_onBack());
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: AppDrawer(
          actions: DrawerActions(
            onDownloads: () => _push(const DownloadsScreen()),
            onNotifications: () => _push(const NotificationsScreen()),
            onScanQr: () => unawaited(Navigator.of(context).push<String>(QrScannerScreen.route())),
            onPhotoTools: () => _push(const ImageToolsScreen()),
            onSettings: () => _push(const SettingsScreen()),
            onLogout: _logout,
          ),
        ),
        appBar: AppBar(
          titleSpacing: 0,
          title: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const AppLogo(size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  current == AppTab.home ? AppConfig.shortName : (_titles[current] ?? current.label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: <Widget>[
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _refresh,
            ),
            IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.share_rounded),
              onPressed: _openShareSheet,
            ),
            IconButton(
              tooltip: AppStrings.notifications,
              onPressed: () => _push(const NotificationsScreen()),
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text(unread > 99 ? '99+' : '$unread'),
                child: const Icon(Icons.notifications_none_rounded),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: IndexedStack(
          index: current.index,
          children: <Widget>[
            for (final AppTab tab in AppTab.values)
              navigation.isVisited(tab)
                  ? NexusWebView(
                      key: PageStorageKey<String>('tab_${tab.name}'),
                      tab: tab,
                      initialUrl: tab.url,
                      onTitleChanged: (String title) => setState(() => _titles[tab] = title),
                    )
                  : const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: current.index,
          onDestinationSelected: (int index) {
            final AppTab tab = AppTab.values[index];
            if (tab == current) {
              unawaited(navigation.reselect(tab));
            } else {
              unawaited(HapticFeedback.selectionClick());
              navigation.select(tab);
            }
          },
          destinations: <Widget>[
            for (final AppTab tab in AppTab.values)
              NavigationDestination(
                icon: Icon(tab.icon),
                selectedIcon: Icon(tab.selectedIcon),
                label: tab.label,
              ),
          ],
        ),
      ),
    );
  }
}
