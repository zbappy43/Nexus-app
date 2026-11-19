import 'dart:convert';

import 'package:flutter/services.dart';

/// JavaScript injected into the website, loaded once from the asset bundle.
abstract final class WebAssets {
  static String _bridge = '';
  static String _autoLogin = '';

  static Future<void> load() async {
    _bridge = await rootBundle.loadString('assets/js/nexus_bridge.js');
    _autoLogin = await rootBundle.loadString('assets/js/auto_login.js');
  }

  /// Defines `window.NexusApp` (see assets/js/nexus_bridge.js).
  static String get bridge => _bridge;

  /// Login-form filler with the credentials safely JSON-encoded.
  static String autoLogin({required String username, required String password}) => _autoLogin
      .replaceFirst('__NEXUS_USERNAME__', jsonEncode(username))
      .replaceFirst('__NEXUS_PASSWORD__', jsonEncode(password));
}
