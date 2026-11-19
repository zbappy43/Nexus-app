import 'dart:async';

import 'package:flutter/services.dart';

import '../constants/app_constants.dart';
import '../utils/url_utils.dart';

/// Receives `https://` App Links and `myapp://` links delivered to
/// `MainActivity` and converts them to website URLs.
class DeepLinkService {
  DeepLinkService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(NativeChannels.deepLinks) {
    _channel.setMethodCallHandler(_onNativeCall);
  }

  final MethodChannel _channel;
  final StreamController<String> _links = StreamController<String>.broadcast();

  /// Website URLs to open, emitted while the app is running.
  Stream<String> get links => _links.stream;

  Future<void> _onNativeCall(MethodCall call) async {
    if (call.method == 'onLink' && call.arguments is String) {
      final String? url = UrlUtils.resolveDeepLink(call.arguments as String);
      if (url != null) _links.add(url);
    }
  }

  /// The link that launched the app (cold start), resolved to a website URL.
  Future<String?> initialLink() async {
    try {
      final String? raw = await _channel.invokeMethod<String>('getInitialLink');
      return raw == null ? null : UrlUtils.resolveDeepLink(raw);
    } on PlatformException {
      return null;
    }
  }
}
