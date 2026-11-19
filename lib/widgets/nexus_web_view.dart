import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../constants/app_config.dart';
import '../core/di/app_services.dart';
import '../core/network/secure_http_client.dart';
import '../core/web/web_assets.dart';
import '../core/web/web_bridge.dart';
import '../models/nav_destination.dart';
import '../providers/auth_provider.dart';
import '../providers/download_provider.dart';
import '../providers/navigation_provider.dart';
import '../repositories/auth_repository.dart';
import '../screens/pdf/pdf_viewer_screen.dart';
import '../screens/webview/popup_webview_screen.dart';
import '../services/permission_service.dart';
import '../utils/app_logger.dart';
import '../utils/file_utils.dart';
import '../utils/ui_utils.dart';
import '../utils/url_utils.dart';
import 'status_view.dart';

enum _PageState { content, offline, error, insecure }

/// The app's WebView: renders the website and connects it to native features.
///
/// Used for each bottom-navigation tab ([tab] set) and for pop-up windows
/// opened by the website ([windowId] set).
class NexusWebView extends StatefulWidget {
  const NexusWebView({
    super.key,
    this.initialUrl,
    this.windowId,
    this.tab,
    this.onTitleChanged,
    this.onCloseWindow,
  }) : assert(initialUrl != null || windowId != null, 'Provide initialUrl or windowId');

  final String? initialUrl;
  final int? windowId;
  final AppTab? tab;
  final ValueChanged<String>? onTitleChanged;
  final VoidCallback? onCloseWindow;

  @override
  State<NexusWebView> createState() => _NexusWebViewState();
}

class _NexusWebViewState extends State<NexusWebView>
    with AutomaticKeepAliveClientMixin
    implements WebTabHandle {
  static final List<WebResourceErrorType> _networkErrors = <WebResourceErrorType>[
    WebResourceErrorType.HOST_LOOKUP,
    WebResourceErrorType.TIMEOUT,
    WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
    WebResourceErrorType.NOT_CONNECTED_TO_INTERNET,
    WebResourceErrorType.NETWORK_CONNECTION_LOST,
    WebResourceErrorType.CANNOT_LOAD_FROM_NETWORK,
    WebResourceErrorType.RESET,
    WebResourceErrorType.IO,
  ];

  late final AppServices _services;
  late final NavigationProvider _navigation;
  late final PullToRefreshController _pullToRefresh;
  StreamSubscription<bool>? _connectivitySubscription;

  InAppWebViewController? _controller;
  Key _webViewKey = UniqueKey();
  _PageState _state = _PageState.content;
  double _progress = 0;
  bool _mainFrameFailed = false;
  bool _isDark = false;
  bool _suppressAutoLogin = false;
  DateTime? _autoLoginAttemptAt;
  String? _pendingUrl;
  String? _lastGoodUrl;
  String? _errorDetails;

  @override
  bool get wantKeepAlive => true;

  String get _startUrl => widget.initialUrl ?? AppConfig.url(AppConfig.homePath);

  @override
  void initState() {
    super.initState();
    _services = context.read<AppServices>();
    _navigation = context.read<NavigationProvider>();
    _pullToRefresh = PullToRefreshController(
      settings: PullToRefreshSettings(color: AppColors.primary),
      onRefresh: () async {
        if (_state != _PageState.content) {
          await _retry();
        } else {
          await _controller?.reload();
        }
      },
    );
    _connectivitySubscription = _services.connectivity.onStatusChange.listen(_onConnectivity);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    if (dark != _isDark) {
      _isDark = dark;
      unawaited(_controller?.setSettings(settings: _settings()));
    }
  }

  @override
  void dispose() {
    unawaited(_connectivitySubscription?.cancel());
    if (widget.tab != null) _navigation.unregister(widget.tab!, this);
    super.dispose();
  }

  InAppWebViewSettings _settings() {
    final bool online = _services.connectivity.isOnline;
    return InAppWebViewSettings(
      javaScriptEnabled: true,
      domStorageEnabled: true,
      databaseEnabled: true,
      cacheEnabled: true,
      cacheMode: online ? CacheMode.LOAD_DEFAULT : CacheMode.LOAD_CACHE_ELSE_NETWORK,
      thirdPartyCookiesEnabled: true,
      useShouldOverrideUrlLoading: true,
      useOnDownloadStart: true,
      useOnRenderProcessGone: true,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      supportMultipleWindows: true,
      javaScriptCanOpenWindowsAutomatically: true,
      geolocationEnabled: true,
      mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
      safeBrowsingEnabled: true,
      isInspectable: kDebugMode,
      allowFileAccess: false,
      allowFileAccessFromFileURLs: false,
      allowUniversalAccessFromFileURLs: false,
      saveFormData: false,
      disableDefaultErrorPage: true,
      algorithmicDarkeningAllowed: _isDark,
      supportZoom: true,
      builtInZoomControls: true,
      displayZoomControls: false,
      useWideViewPort: true,
      loadWithOverviewMode: true,
      textZoom: 100,
      applicationNameForUserAgent: _services.deviceInfo.userAgentSuffix,
      verticalScrollBarEnabled: false,
      overScrollMode: OverScrollMode.IF_CONTENT_SCROLLS,
      hardwareAcceleration: true,
      useHybridComposition: true,
    );
  }

  // ---------------------------------------------------------------------------
  // WebTabHandle
  // ---------------------------------------------------------------------------
  @override
  Future<void> load(String url) async {
    final InAppWebViewController? controller = _controller;
    if (controller == null) {
      _pendingUrl = url;
      return;
    }
    _setState(_PageState.content);
    await controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  @override
  Future<void> reload() => _retry();

  @override
  Future<bool> canGoBack() async => await _controller?.canGoBack() ?? false;

  @override
  Future<void> goBack() async {
    if (_state != _PageState.content) _setState(_PageState.content);
    await _controller?.goBack();
  }

  @override
  Future<String?> currentUrl() async => (await _controller?.getUrl())?.toString() ?? _lastGoodUrl;

  @override
  Future<String?> currentTitle() async => _controller?.getTitle();

  // ---------------------------------------------------------------------------
  // State helpers
  // ---------------------------------------------------------------------------
  void _setState(_PageState state, {String? details}) {
    if (!mounted) return;
    setState(() {
      _state = state;
      _errorDetails = details;
    });
  }

  Future<void> _retry() async {
    final InAppWebViewController? controller = _controller;
    if (controller == null) return;
    if (!_services.connectivity.isOnline && !await _services.connectivity.refresh()) {
      _setState(_PageState.offline);
      await _pullToRefresh.endRefreshing();
      return;
    }
    _setState(_PageState.content);
    final WebUri? current = await controller.getUrl();
    final String target = _lastGoodUrl ?? _startUrl;
    if (current == null || current.toString() == 'about:blank') {
      await controller.loadUrl(urlRequest: URLRequest(url: WebUri(target)));
    } else {
      await controller.reload();
    }
  }

  Future<void> _onConnectivity(bool online) async {
    await _controller?.setSettings(settings: _settings());
    if (online && (_state == _PageState.offline || _state == _PageState.error)) {
      await _retry();
    }
  }

  // ---------------------------------------------------------------------------
  // WebView callbacks
  // ---------------------------------------------------------------------------
  void _onWebViewCreated(InAppWebViewController controller) {
    _controller = controller;
    WebBridge(
      controller: controller,
      services: _services,
      contextProvider: () => mounted ? context : null,
      onLogout: _logout,
    ).register();
    if (widget.tab != null) _navigation.register(widget.tab!, this);
    final String? pending = _pendingUrl;
    _pendingUrl = null;
    if (pending != null) unawaited(load(pending));
  }

  void _onLoadStart(InAppWebViewController controller, WebUri? url) {
    _mainFrameFailed = false;
    if (url != null && url.path.startsWith(Uri.parse(AppConfig.url(AppConfig.logoutPath)).path)) {
      _suppressAutoLogin = true;
    }
  }

  Future<void> _onLoadStop(InAppWebViewController controller, WebUri? url) async {
    await _pullToRefresh.endRefreshing();
    if (mounted) setState(() => _progress = 1);
    if (_mainFrameFailed) return;
    if (!await _verifyCertificatePins(url)) return;
    _lastGoodUrl = url?.toString();
    if (_state != _PageState.content) _setState(_PageState.content);
    await _maybeAutoLogin(url);
  }

  void _onProgressChanged(InAppWebViewController controller, int progress) {
    if (!mounted) return;
    setState(() => _progress = progress / 100);
    if (progress == 100) unawaited(_pullToRefresh.endRefreshing());
  }

  void _onReceivedError(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceError error,
  ) {
    if (request.isForMainFrame != true || error.type == WebResourceErrorType.CANCELLED) return;
    _mainFrameFailed = true;
    unawaited(_pullToRefresh.endRefreshing());
    final bool network = _networkErrors.any((WebResourceErrorType t) => t == error.type);
    if (network || !_services.connectivity.isOnline) {
      _setState(_PageState.offline);
      unawaited(_services.connectivity.refresh());
    } else {
      _setState(_PageState.error, details: error.description);
    }
  }

  void _onReceivedHttpError(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceResponse response,
  ) {
    final int status = response.statusCode ?? 0;
    if (request.isForMainFrame == true && status >= 500) {
      _mainFrameFailed = true;
      _setState(_PageState.error, details: 'Server error ($status)');
    }
  }

  Future<NavigationActionPolicy?> _shouldOverrideUrlLoading(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final WebUri? uri = action.request.url;
    if (uri == null) return NavigationActionPolicy.ALLOW;
    final String url = uri.toString();

    switch (UrlUtils.classify(uri)) {
      case UrlAction.block:
        return NavigationActionPolicy.CANCEL;
      case UrlAction.external:
        final bool opened = await _services.launcher.openExternal(url);
        if (!opened && mounted) UiUtils.showSnack(context, 'No app found to open this link');
        return NavigationActionPolicy.CANCEL;
      case UrlAction.internal:
        break;
    }

    if (uri.scheme == AppConfig.deepLinkScheme) {
      final String? target = UrlUtils.resolveDeepLink(url);
      if (target != null) await controller.loadUrl(urlRequest: URLRequest(url: WebUri(target)));
      return NavigationActionPolicy.CANCEL;
    }
    // Never load first-party pages over plain HTTP.
    if (uri.scheme == 'http' && UrlUtils.isFirstParty(uri)) {
      await controller.loadUrl(
        urlRequest: URLRequest(url: WebUri(uri.replace(scheme: 'https').toString())),
      );
      return NavigationActionPolicy.CANCEL;
    }
    if (action.isForMainFrame && FileUtils.isPdf(url)) {
      unawaited(_openPdf(url));
      return NavigationActionPolicy.CANCEL;
    }
    return NavigationActionPolicy.ALLOW;
  }

  Future<void> _onDownloadStart(
    InAppWebViewController controller,
    DownloadStartRequest request,
  ) async {
    final String url = request.url.toString();
    final String name = request.suggestedFilename ??
        FileUtils.fileNameFromContentDisposition(request.contentDisposition) ??
        FileUtils.fileNameFromUrl(url, mimeType: request.mimeType);
    final DownloadProvider downloads = context.read<DownloadProvider>();

    if (url.startsWith('data:')) {
      await downloads.saveBase64(base64Data: url, fileName: name, mimeType: request.mimeType);
      if (mounted) UiUtils.showSnack(context, 'Saved $name');
      return;
    }
    if (url.startsWith('blob:')) {
      await controller.evaluateJavascript(
        source: 'window.__nexusSaveBlob && window.__nexusSaveBlob(${jsonEncode(url)}, ${jsonEncode(name)});',
      );
      return;
    }
    if (FileUtils.isPdf(name, mimeType: request.mimeType) && mounted) {
      final bool? view = await _askPdfAction(name);
      if (view == null) return;
      if (view) {
        await _openPdf(url, title: name);
        return;
      }
    }
    await downloads.download(
      url: url,
      suggestedFileName: name,
      mimeType: request.mimeType,
      contentDisposition: request.contentDisposition,
      userAgent: request.userAgent,
    );
    if (mounted) UiUtils.showSnack(context, 'Downloading $name…');
  }

  Future<bool?> _askPdfAction(String name) => showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        builder: (BuildContext ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.error),
                title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('View in app'),
                onTap: () => Navigator.of(ctx).pop(true),
              ),
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: const Text('Download'),
                onTap: () => Navigator.of(ctx).pop(false),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );

  Future<void> _openPdf(String url, {String? title}) async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(PdfViewerScreen.route(url: url, title: title));
  }

  Future<bool?> _onCreateWindow(
    InAppWebViewController controller,
    CreateWindowAction action,
  ) async {
    if (!mounted) return false;
    unawaited(Navigator.of(context).push<void>(PopupWebViewScreen.route(windowId: action.windowId)));
    return true;
  }

  void _onCloseWindow(InAppWebViewController controller) => widget.onCloseWindow?.call();

  Future<PermissionResponse?> _onPermissionRequest(
    InAppWebViewController controller,
    PermissionRequest request,
  ) async {
    final bool secureOrigin = request.origin.scheme == 'https';
    final Set<AppPermission> needed = <AppPermission>{
      for (final PermissionResourceType r in request.resources)
        if (r == PermissionResourceType.CAMERA)
          AppPermission.camera
        else if (r == PermissionResourceType.MICROPHONE)
          AppPermission.microphone
        else if (r == PermissionResourceType.GEOLOCATION)
          AppPermission.location,
    };
    bool granted = secureOrigin;
    for (final AppPermission permission in needed) {
      if (!granted) break;
      granted = await _services.permissions.ensure(permission);
    }
    return PermissionResponse(
      resources: request.resources,
      action: granted ? PermissionResponseAction.GRANT : PermissionResponseAction.DENY,
    );
  }

  Future<GeolocationPermissionShowPromptResponse?> _onGeolocationPrompt(
    InAppWebViewController controller,
    String origin,
  ) async {
    final bool allowed = origin.startsWith('https://') &&
        await _services.permissions.ensure(AppPermission.location);
    return GeolocationPermissionShowPromptResponse(origin: origin, allow: allowed, retain: allowed);
  }

  Future<void> _onEnterFullscreen(InAppWebViewController controller) async {
    // Fullscreen video: allow landscape and auto-rotation, hide system bars.
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _onExitFullscreen(InAppWebViewController controller) async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
  }

  void _onRenderProcessGone(InAppWebViewController controller, RenderProcessGoneDetail detail) {
    AppLogger.error('WebView renderer gone (crash: ${detail.didCrash}); recreating');
    if (!mounted) return;
    _pendingUrl = _lastGoodUrl ?? _startUrl;
    setState(() {
      _controller = null;
      _webViewKey = UniqueKey();
    });
  }

  Future<ServerTrustAuthResponse?> _onServerTrust(
    InAppWebViewController controller,
    URLAuthenticationChallenge challenge,
  ) async {
    // Only invoked for invalid certificates on Android: always refuse.
    return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.CANCEL);
  }

  // ---------------------------------------------------------------------------
  // Security & login automation
  // ---------------------------------------------------------------------------
  Future<bool> _verifyCertificatePins(WebUri? url) async {
    final List<String> pins = AppConfig.sslPins;
    if (pins.isEmpty || url == null || url.scheme != 'https' || !UrlUtils.isFirstParty(url)) {
      return true;
    }
    final SslCertificate? certificate = await _controller?.getCertificate();
    final Uint8List? der = certificate?.x509Certificate?.encoded;
    if (der != null && SecureHttpClient.matchesPins(der, pins)) return true;
    AppLogger.error('Certificate pinning failed for ${url.host}');
    await _controller?.stopLoading();
    await _controller?.loadData(data: '<html><body></body></html>');
    _mainFrameFailed = true;
    _setState(_PageState.insecure);
    return false;
  }

  Future<void> _maybeAutoLogin(WebUri? url) async {
    if (url == null || !UrlUtils.isFirstParty(url) || !mounted) return;
    final String loginPath = Uri.parse(AppConfig.url(AppConfig.loginPath)).path;
    if (!url.path.startsWith(loginPath)) {
      _autoLoginAttemptAt = null;
      return;
    }
    if (_suppressAutoLogin) return;
    final AuthProvider auth = context.read<AuthProvider>();
    final DateTime? lastAttempt = _autoLoginAttemptAt;
    if (lastAttempt != null) {
      // Back on the login page right after submitting: credentials rejected.
      _autoLoginAttemptAt = null;
      if (DateTime.now().difference(lastAttempt) < const Duration(seconds: 20)) {
        await auth.onAutoLoginRejected();
        if (mounted) UiUtils.showSnack(context, 'Saved login expired. Please sign in again.');
      }
      return;
    }
    final SavedCredentials? credentials = await auth.credentialsForAutoLogin();
    if (credentials == null) return;
    _autoLoginAttemptAt = DateTime.now();
    final Object? result = await _controller?.evaluateJavascript(
      source: WebAssets.autoLogin(username: credentials.username, password: credentials.password),
    );
    if (result != 'submitted') _autoLoginAttemptAt = null;
  }

  Future<void> _logout() async {
    if (!mounted) return;
    await context.read<AuthProvider>().logout();
    _suppressAutoLogin = true;
    await _controller?.loadUrl(
      urlRequest: URLRequest(url: WebUri(AppConfig.url(AppConfig.loginPath))),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: <Widget>[
        InAppWebView(
          key: _webViewKey,
          windowId: widget.windowId,
          initialUrlRequest: widget.windowId == null
              ? URLRequest(url: WebUri(_pendingUrl ?? _startUrl))
              : null,
          initialSettings: _settings(),
          initialUserScripts: UnmodifiableListView<UserScript>(<UserScript>[
            UserScript(
              source: WebAssets.bridge,
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              allowedOriginRules: <String>{
                'https://${AppConfig.webHost}',
                'https://*.${AppConfig.webHost}',
              },
            ),
          ]),
          pullToRefreshController: _pullToRefresh,
          onWebViewCreated: _onWebViewCreated,
          onLoadStart: _onLoadStart,
          onLoadStop: _onLoadStop,
          onProgressChanged: _onProgressChanged,
          onTitleChanged: (InAppWebViewController c, String? title) {
            if (title != null && title.isNotEmpty) widget.onTitleChanged?.call(title);
          },
          onReceivedError: _onReceivedError,
          onReceivedHttpError: _onReceivedHttpError,
          shouldOverrideUrlLoading: _shouldOverrideUrlLoading,
          onDownloadStartRequest: _onDownloadStart,
          onCreateWindow: _onCreateWindow,
          onCloseWindow: _onCloseWindow,
          onPermissionRequest: _onPermissionRequest,
          onGeolocationPermissionsShowPrompt: _onGeolocationPrompt,
          onEnterFullscreen: _onEnterFullscreen,
          onExitFullscreen: _onExitFullscreen,
          onRenderProcessGone: _onRenderProcessGone,
          onReceivedServerTrustAuthRequest: _onServerTrust,
        ),
        if (_progress < 1 && _state == _PageState.content)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(value: _progress, minHeight: 3),
          ),
        if (_state != _PageState.content)
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: switch (_state) {
                _PageState.offline => StatusView.offline(key: const ValueKey<String>('offline'), onRetry: _retry),
                _PageState.insecure => StatusView.insecure(key: const ValueKey<String>('insecure'), onRetry: _retry),
                _ => StatusView.error(
                    key: const ValueKey<String>('error'),
                    onReload: _retry,
                    details: _errorDetails,
                    onHome: widget.tab == null ? null : () => load(widget.tab!.url),
                  ),
              },
            ),
          ),
      ],
    );
  }
}
