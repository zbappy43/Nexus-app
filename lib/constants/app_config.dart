/// Central, compile-time application configuration.
///
/// Every value can be overridden at build time without touching the source:
///
/// ```bash
/// flutter build appbundle --release \
///   --dart-define=BASE_URL=https://nexusconsumers.com \
///   --dart-define=ONESIGNAL_APP_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
///   --dart-define=SSL_PINS=base64Sha256Pin1,base64Sha256Pin2
/// ```
///
/// Keep `BASE_URL` in sync with `nexus.webHost` in `android/gradle.properties`
/// so that verified App Links (https deep links) route into the app.
abstract final class AppConfig {
  static const String appName = 'Nexus Consumers Limited';
  static const String shortName = 'Nexus Consumers';
  static const String packageName = 'com.nexus.consumers';

  /// Root URL of the website rendered by the app (no trailing slash).
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://www.nexusglobalplc.com',
  );

  /// Custom deep-link scheme, e.g. `myapp://wallet` → `$baseUrl/wallet`.
  static const String deepLinkScheme = String.fromEnvironment(
    'DEEP_LINK_SCHEME',
    defaultValue: 'myapp',
  );

  // ---------------------------------------------------------------------------
  // Website routes. Each tab / drawer entry maps to one of these paths.
  // ---------------------------------------------------------------------------
  static const String homePath = String.fromEnvironment('PATH_HOME', defaultValue: '/');
  static const String teamPath = String.fromEnvironment('PATH_TEAM', defaultValue: '/team');
  static const String walletPath = String.fromEnvironment('PATH_WALLET', defaultValue: '/wallet');
  static const String profilePath = String.fromEnvironment('PATH_PROFILE', defaultValue: '/profile');
  static const String trainingPath = String.fromEnvironment('PATH_TRAINING', defaultValue: '/training');
  static const String noticePath = String.fromEnvironment('PATH_NOTICE', defaultValue: '/notice');
  static const String supportPath = String.fromEnvironment('PATH_SUPPORT', defaultValue: '/support');
  static const String contactPath = String.fromEnvironment('PATH_CONTACT', defaultValue: '/contact');
  static const String aboutPath = String.fromEnvironment('PATH_ABOUT', defaultValue: '/about');
  static const String privacyPath = String.fromEnvironment('PATH_PRIVACY', defaultValue: '/privacy-policy');
  static const String loginPath = String.fromEnvironment('PATH_LOGIN', defaultValue: '/login');
  static const String logoutPath = String.fromEnvironment('PATH_LOGOUT', defaultValue: '/logout');
  static const String registerPath = String.fromEnvironment('PATH_REGISTER', defaultValue: '/register');

  /// Query parameter appended to the register URL for referral sharing.
  static const String referralQueryKey = String.fromEnvironment('REFERRAL_KEY', defaultValue: 'ref');

  /// JSON document describing the latest / minimum supported app versions.
  /// Format (all fields optional except `latest_version`):
  /// ```json
  /// {
  ///   "latest_version": "1.0.3",
  ///   "min_supported_version": "1.0.0",
  ///   "message": "A new version is available.",
  ///   "store_url": "https://play.google.com/store/apps/details?id=com.nexus.consumers"
  /// }
  /// ```
  static const String versionCheckUrl = String.fromEnvironment(
    'VERSION_CHECK_URL',
    defaultValue: '$baseUrl/app/version.json',
  );

  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=$packageName';
  static const String playStoreMarketUrl = 'market://details?id=$packageName';

  /// OneSignal App ID. Push via OneSignal is skipped when empty.
  static const String oneSignalAppId = String.fromEnvironment('ONESIGNAL_APP_ID');

  /// Base64 SHA-256 fingerprints of the DER encoded server certificate(s)
  /// for the website host. When non-empty, every native HTTP request and every
  /// main-frame page load in the WebView is verified against these pins.
  /// Generate with `tools/generate_ssl_pins.sh www.nexusglobalplc.com`.
  static const String _sslPinsRaw = String.fromEnvironment('SSL_PINS');

  static List<String> get sslPins => _sslPinsRaw
      .split(',')
      .map((String pin) => pin.trim())
      .where((String pin) => pin.isNotEmpty)
      .toList(growable: false);

  /// Blocks screenshots and screen recording (FLAG_SECURE). Can be disabled
  /// for store screenshot sessions with `--dart-define=SECURE_SCREEN=false`.
  static const bool secureScreen = bool.fromEnvironment('SECURE_SCREEN', defaultValue: true);

  /// Extra hosts (besides [baseUrl]'s host) that are treated as first-party.
  static const List<String> trustedHosts = <String>[];

  /// Splash screen display duration.
  static const Duration splashDuration = Duration(seconds: 2);

  /// Network timeouts.
  static const Duration httpTimeout = Duration(seconds: 15);

  /// Window in which a second back press exits the app.
  static const Duration exitBackPressWindow = Duration(seconds: 2);

  static Uri get baseUri => Uri.parse(baseUrl);

  /// Registrable website host without a leading `www.` (e.g. `nexusglobalplc.com`).
  /// Both the bare domain and every subdomain (including `www`) are first-party.
  static String get webHost {
    final String host = baseUri.host.toLowerCase();
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  /// Builds an absolute website URL from a [path] (which may already be absolute).
  static String url(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final String normalized = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$normalized';
  }
}
