import 'package:url_launcher/url_launcher.dart';

import '../constants/app_config.dart';
import '../utils/app_logger.dart';
import '../utils/url_utils.dart';

/// Opens URLs in other apps: dialer, e-mail, SMS, WhatsApp, Messenger,
/// Facebook, YouTube, Maps, Play Store and the system browser.
class LauncherService {
  Future<bool> openExternal(String url) async {
    if (url.startsWith('intent://')) return _openIntentUrl(url);
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return false;
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication)) return true;
    } on Object catch (e) {
      AppLogger.debug('Non-browser launch failed for $url: $e');
    }
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object catch (e, st) {
      AppLogger.error('Unable to open $url', error: e, stackTrace: st);
      return _webFallback(uri);
    }
  }

  /// Opens a URL inside a Custom Tab (in-app browser).
  Future<bool> openInAppBrowser(String url) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } on Object {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<bool> _openIntentUrl(String url) async {
    final ({String? fallback, String? primary}) parsed = UrlUtils.parseIntentUrl(url);
    if (parsed.primary != null) {
      try {
        if (await launchUrl(Uri.parse(parsed.primary!),
            mode: LaunchMode.externalNonBrowserApplication)) {
          return true;
        }
      } on Object {
        // Fall through to the fallback URL.
      }
    }
    if (parsed.fallback != null) {
      return launchUrl(Uri.parse(parsed.fallback!), mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// When the native app (e.g. WhatsApp) is missing, try its web equivalent.
  Future<bool> _webFallback(Uri uri) async {
    Uri? web;
    switch (uri.scheme) {
      case 'whatsapp':
        final String? phone = uri.queryParameters['phone'];
        final String? text = uri.queryParameters['text'];
        web = Uri.https('wa.me', '/${phone ?? ''}', <String, String>{'text': ?text});
      case 'fb-messenger' || 'messenger':
        web = Uri.https('m.me', uri.path);
      case 'geo':
        final String query = uri.queryParameters['q'] ?? uri.path;
        web = Uri.https('www.google.com', '/maps/search/', <String, String>{'api': '1', 'query': query});
      case 'market':
        web = Uri.parse(AppConfig.playStoreUrl);
    }
    if (web == null) return false;
    try {
      return await launchUrl(web, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }

  Future<bool> openPlayStore() async {
    try {
      if (await launchUrl(Uri.parse(AppConfig.playStoreMarketUrl),
          mode: LaunchMode.externalNonBrowserApplication)) {
        return true;
      }
    } on Object {
      // Play Store app missing; use the web listing.
    }
    return launchUrl(Uri.parse(AppConfig.playStoreUrl), mode: LaunchMode.externalApplication);
  }
}
