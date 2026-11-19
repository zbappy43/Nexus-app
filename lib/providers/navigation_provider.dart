import 'package:flutter/foundation.dart';

import '../constants/app_config.dart';
import '../models/nav_destination.dart';

/// Operations the shell can perform on a tab's WebView.
abstract interface class WebTabHandle {
  Future<void> load(String url);
  Future<void> reload();
  Future<bool> canGoBack();
  Future<void> goBack();
  Future<String?> currentUrl();
  Future<String?> currentTitle();
}

/// Bottom-navigation state and URL routing between tabs.
class NavigationProvider extends ChangeNotifier {
  AppTab _current = AppTab.home;
  final Map<AppTab, WebTabHandle> _handles = <AppTab, WebTabHandle>{};
  final Map<AppTab, String> _pendingUrls = <AppTab, String>{};
  final Set<AppTab> _visited = <AppTab>{AppTab.home};

  AppTab get current => _current;

  int get currentIndex => _current.index;

  /// Tabs are built lazily on first visit to keep start-up fast.
  bool isVisited(AppTab tab) => _visited.contains(tab);

  WebTabHandle? get currentHandle => _handles[_current];

  void register(AppTab tab, WebTabHandle handle) {
    _handles[tab] = handle;
    final String? pending = _pendingUrls.remove(tab);
    if (pending != null) handle.load(pending);
  }

  void unregister(AppTab tab, WebTabHandle handle) {
    if (identical(_handles[tab], handle)) _handles.remove(tab);
  }

  void select(AppTab tab) {
    if (tab == _current) return;
    _current = tab;
    _visited.add(tab);
    notifyListeners();
  }

  /// Tapping the active tab again returns it to its start page.
  Future<void> reselect(AppTab tab) async {
    await _handles[tab]?.load(tab.url);
  }

  /// Opens [url] in the tab whose path it matches, otherwise in Home.
  Future<void> openUrl(String url) async {
    final AppTab tab = _tabFor(url);
    select(tab);
    final WebTabHandle? handle = _handles[tab];
    if (handle == null) {
      _pendingUrls[tab] = url;
    } else {
      await handle.load(url);
    }
  }

  Future<void> openPath(String path) => openUrl(AppConfig.url(path));

  AppTab _tabFor(String url) {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return AppTab.home;
    final String path = uri.path.isEmpty ? '/' : uri.path;
    for (final AppTab tab in AppTab.values) {
      if (tab == AppTab.home) continue;
      final String tabPath = Uri.parse(tab.url).path;
      if (path == tabPath || path.startsWith('$tabPath/')) return tab;
    }
    return AppTab.home;
  }

  /// Back navigation: WebView history → Home tab → (caller handles exit).
  /// Returns `true` when the back press was consumed.
  Future<bool> handleBack() async {
    final WebTabHandle? handle = currentHandle;
    if (handle != null && await handle.canGoBack()) {
      await handle.goBack();
      return true;
    }
    if (_current != AppTab.home) {
      select(AppTab.home);
      return true;
    }
    return false;
  }
}
