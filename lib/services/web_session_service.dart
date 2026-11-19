import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../utils/app_logger.dart';

/// Cookie and storage management for the shared WebView profile.
///
/// All WebViews share Android's single `CookieManager`, so a login on one
/// tab is immediately valid on the others and survives app restarts
/// (session persistence).
class WebSessionService {
  CookieManager get _cookies => CookieManager.instance();

  /// `Cookie` header for native requests (downloads, PDF fetching) so they
  /// are authenticated exactly like the WebView.
  Future<String?> cookieHeaderFor(String url) async {
    try {
      final List<Cookie> cookies = await _cookies.getCookies(url: WebUri(url));
      if (cookies.isEmpty) return null;
      return cookies.map((Cookie c) => '${c.name}=${c.value}').join('; ');
    } on Object catch (e) {
      AppLogger.debug('Unable to read cookies for $url: $e');
      return null;
    }
  }

  /// Headers to replay WebView authentication for a native request.
  Future<Map<String, String>> authHeadersFor(String url, {String? userAgent}) async {
    final String? cookie = await cookieHeaderFor(url);
    return <String, String>{
      'Cookie': ?cookie,
      'User-Agent': ?userAgent,
    };
  }

  /// Signs the device out of the website: cookies, local/session storage,
  /// IndexedDB and HTTP cache are wiped.
  Future<void> clearSession() async {
    await _cookies.deleteAllCookies();
    await WebStorageManager.instance().deleteAllData();
    await InAppWebViewController.clearAllCache();
  }

  /// Clears only the HTTP cache (Settings → Clear cache).
  Future<void> clearCache() => InAppWebViewController.clearAllCache();
}
