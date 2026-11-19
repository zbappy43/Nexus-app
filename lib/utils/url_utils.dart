import '../constants/app_config.dart';

/// How the WebView should treat a navigation request.
enum UrlAction {
  /// Load inside the WebView.
  internal,

  /// Hand over to another app (dialer, mail, WhatsApp, Maps, Facebook ...).
  external,

  /// Blocked (e.g. `javascript:` or `file:` from remote content).
  block,
}

abstract final class UrlUtils {
  /// Schemes that always leave the app.
  static const Set<String> externalSchemes = <String>{
    'tel', 'mailto', 'sms', 'smsto', 'mms', 'geo', 'market', 'intent', //
    'whatsapp', 'fb', 'fb-messenger', 'messenger', 'tg', 'viber', 'skype', //
    'youtube', 'vnd.youtube', 'upi', 'bkash', 'nagad', 'maps', 'comgooglemaps',
  };

  /// Hosts whose links open in their native apps (or the browser).
  static const List<String> externalHosts = <String>[
    'wa.me', 'api.whatsapp.com', 'web.whatsapp.com', 'chat.whatsapp.com', //
    'maps.google.com', 'maps.app.goo.gl', 'goo.gl', //
    'facebook.com', 'fb.com', 'fb.me', 'fb.watch', 'm.me', 'messenger.com', //
    'youtube.com', 'youtu.be', 'instagram.com', 'twitter.com', 'x.com', //
    't.me', 'telegram.me', 'linkedin.com', 'tiktok.com', //
    'play.google.com', 'apps.apple.com',
  ];

  static const Set<String> _blockedSchemes = <String>{'javascript', 'file', 'content'};

  static bool isFirstPartyHost(String? host) {
    if (host == null || host.isEmpty) return false;
    final String h = host.toLowerCase();
    final List<String> trusted = <String>[AppConfig.webHost, ...AppConfig.trustedHosts];
    return trusted.any((String t) => h == t || h.endsWith('.$t'));
  }

  static bool isFirstParty(Uri uri) => isFirstPartyHost(uri.host);

  static bool _matchesHost(String host, String pattern) =>
      host == pattern || host.endsWith('.$pattern');

  static bool isGoogleMaps(Uri uri) {
    final String host = uri.host.toLowerCase();
    return host.startsWith('maps.') ||
        (_matchesHost(host, 'google.com') && uri.path.startsWith('/maps'));
  }

  /// Decides where a URL should be handled.
  static UrlAction classify(Uri uri) {
    final String scheme = uri.scheme.toLowerCase();
    if (scheme == 'about' || scheme == 'data' || scheme == 'blob') return UrlAction.internal;
    if (_blockedSchemes.contains(scheme)) return UrlAction.block;
    if (scheme == AppConfig.deepLinkScheme) return UrlAction.internal;
    // Known app schemes ([externalSchemes]) and any other custom scheme are
    // handed to Android, which resolves them to the matching installed app.
    if (scheme != 'http' && scheme != 'https') return UrlAction.external;
    if (isFirstParty(uri)) return UrlAction.internal;
    final String host = uri.host.toLowerCase();
    if (isGoogleMaps(uri)) return UrlAction.external;
    if (externalHosts.any((String pattern) => _matchesHost(host, pattern))) {
      return UrlAction.external;
    }
    // Other https sites (payment gateways, OAuth providers …) stay in-app.
    return UrlAction.internal;
  }

  /// Maps `myapp://wallet?tab=2` and verified `https://` App Links to a
  /// website URL that the WebView can load. Returns `null` for foreign links.
  static String? resolveDeepLink(String link) {
    final Uri? uri = Uri.tryParse(link.trim());
    if (uri == null) return null;
    if (uri.scheme == AppConfig.deepLinkScheme) {
      // In `myapp://wallet/history` the first segment is parsed as the host.
      final List<String> segments = <String>[
        if (uri.host.isNotEmpty) uri.host,
        ...uri.pathSegments.where((String s) => s.isNotEmpty),
      ];
      final Uri target = AppConfig.baseUri.replace(
        path: '/${segments.join('/')}',
        query: uri.hasQuery ? uri.query : null,
        fragment: uri.hasFragment ? uri.fragment : null,
      );
      return target.toString();
    }
    if ((uri.scheme == 'https' || uri.scheme == 'http') && isFirstParty(uri)) {
      return uri.replace(scheme: 'https').toString();
    }
    return null;
  }

  /// Parses an Android `intent://` URL into a launchable URL and its fallback.
  static ({String? primary, String? fallback}) parseIntentUrl(String url) {
    final int hashIndex = url.indexOf('#Intent;');
    if (hashIndex < 0) return (primary: null, fallback: null);
    final String target = url.substring('intent://'.length, hashIndex);
    final String params = url.substring(hashIndex + '#Intent;'.length);
    String? scheme;
    String? fallback;
    for (final String part in params.split(';')) {
      if (part.startsWith('scheme=')) scheme = part.substring(7);
      if (part.startsWith('S.browser_fallback_url=')) {
        fallback = Uri.decodeComponent(part.substring('S.browser_fallback_url='.length));
      }
    }
    final String? primary = scheme == null ? null : '$scheme://$target';
    return (primary: primary, fallback: fallback);
  }

  /// Appends the referral code to the registration URL.
  static String referralLink(String? code) {
    final Uri register = Uri.parse(AppConfig.url(AppConfig.registerPath));
    if (code == null || code.trim().isEmpty) return register.toString();
    return register.replace(queryParameters: <String, String>{
      ...register.queryParameters,
      AppConfig.referralQueryKey: code.trim(),
    }).toString();
  }
}
