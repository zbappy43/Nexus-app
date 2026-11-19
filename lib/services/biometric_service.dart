import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../utils/app_logger.dart';

/// What the device offers for biometric authentication.
class BiometricCapability {
  const BiometricCapability({
    required this.isSupported,
    required this.hasFingerprint,
    required this.hasFace,
    required this.isEnrolled,
  });

  static const BiometricCapability none = BiometricCapability(
    isSupported: false,
    hasFingerprint: false,
    hasFace: false,
    isEnrolled: false,
  );

  final bool isSupported;
  final bool hasFingerprint;
  final bool hasFace;
  final bool isEnrolled;

  bool get isAvailable => isSupported && isEnrolled;

  String get label {
    if (hasFace && hasFingerprint) return 'Fingerprint / Face unlock';
    if (hasFace) return 'Face unlock';
    if (hasFingerprint) return 'Fingerprint';
    return 'Biometric unlock';
  }
}

/// Fingerprint / face authentication via `local_auth` (BiometricPrompt).
class BiometricService {
  BiometricService({LocalAuthentication? auth}) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<BiometricCapability> capability() async {
    try {
      final bool supported = await _auth.isDeviceSupported();
      if (!supported) return BiometricCapability.none;
      final bool canCheck = await _auth.canCheckBiometrics;
      final List<BiometricType> types = await _auth.getAvailableBiometrics();
      return BiometricCapability(
        isSupported: supported,
        isEnrolled: canCheck && types.isNotEmpty,
        hasFingerprint: types.contains(BiometricType.fingerprint) ||
            types.contains(BiometricType.strong),
        hasFace: types.contains(BiometricType.face) || types.contains(BiometricType.weak),
      );
    } on PlatformException catch (e) {
      AppLogger.debug('Biometric capability check failed: ${e.code}');
      return BiometricCapability.none;
    }
  }

  /// Shows the system biometric prompt. When [allowDeviceCredential] is true,
  /// PIN / pattern / password can be used as a fallback.
  Future<bool> authenticate({
    required String reason,
    bool allowDeviceCredential = true,
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: !allowDeviceCredential,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (e) {
      AppLogger.debug('Biometric authentication error: ${e.code}');
      return false;
    } on PlatformException catch (e) {
      AppLogger.debug('Biometric authentication error: ${e.code}');
      return false;
    }
  }
}
