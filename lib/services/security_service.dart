import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../constants/app_config.dart';
import '../constants/app_constants.dart';
import '../utils/app_logger.dart';

/// Bridges to `MainActivity` for screenshot / screen-recording protection.
///
/// * `FLAG_SECURE` blocks screenshots, screen recording, casting and the
///   recent-apps thumbnail.
/// * On Android 15+ the activity additionally reports when the window is being
///   recorded so the UI can be obscured as a second line of defence.
class SecurityService {
  SecurityService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(NativeChannels.security) {
    _channel.setMethodCallHandler(_onNativeCall);
  }

  final MethodChannel _channel;

  /// `true` while Android reports an active screen recording of the app.
  final ValueNotifier<bool> isBeingRecorded = ValueNotifier<bool>(false);

  Future<void> _onNativeCall(MethodCall call) async {
    if (call.method == 'onScreenRecordingChanged') {
      isBeingRecorded.value = call.arguments == true;
    }
  }

  Future<void> applyDefaultPolicy() => setSecureScreen(enabled: AppConfig.secureScreen);

  Future<void> setSecureScreen({required bool enabled}) async {
    try {
      await _channel.invokeMethod<void>('setSecure', <String, bool>{'enabled': enabled});
    } on PlatformException catch (e, st) {
      AppLogger.error('setSecure failed', error: e, stackTrace: st);
    }
  }
}
