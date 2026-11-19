import 'package:flutter/foundation.dart';

import '../constants/app_strings.dart';
import '../repositories/auth_repository.dart';
import '../repositories/settings_repository.dart';
import '../services/biometric_service.dart';
import '../services/onesignal_service.dart';
import '../services/web_session_service.dart';

/// Login persistence, biometric app lock and logout.
///
/// * **Remember login** – credentials typed into the website's login form are
///   captured by the JS bridge and stored encrypted in the Keystore.
/// * **Auto login** – when the website shows its login form and credentials
///   are stored, they are filled in and submitted automatically.
/// * **Biometric lock** – the app content is hidden behind fingerprint / face
///   authentication on launch and after [relockAfter] in the background.
class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required SettingsRepository settings,
    required AuthRepository auth,
    required BiometricService biometrics,
    required WebSessionService webSession,
    required OneSignalService oneSignal,
  })  : _settings = settings,
        _auth = auth,
        _biometrics = biometrics,
        _webSession = webSession,
        _oneSignal = oneSignal,
        _biometricEnabled = settings.biometricEnabled,
        _rememberLogin = settings.rememberLogin,
        _autoLogin = settings.autoLogin,
        _locked = settings.biometricEnabled;

  static const Duration relockAfter = Duration(seconds: 60);

  final SettingsRepository _settings;
  final AuthRepository _auth;
  final BiometricService _biometrics;
  final WebSessionService _webSession;
  final OneSignalService _oneSignal;

  bool _biometricEnabled;
  bool _rememberLogin;
  bool _autoLogin;
  bool _locked;
  bool _authenticating = false;
  bool _hasSavedCredentials = false;
  BiometricCapability _capability = BiometricCapability.none;
  DateTime? _backgroundedAt;

  bool get biometricEnabled => _biometricEnabled;
  bool get rememberLogin => _rememberLogin;
  bool get autoLogin => _autoLogin;
  bool get isLocked => _locked;
  bool get isAuthenticating => _authenticating;
  bool get hasSavedCredentials => _hasSavedCredentials;
  BiometricCapability get capability => _capability;

  Future<void> load() async {
    _capability = await _biometrics.capability();
    _hasSavedCredentials = await _auth.hasCredentials();
    // Biometrics removed from the device: never lock the user out.
    if (_biometricEnabled && !_capability.isSupported) {
      _biometricEnabled = false;
      _locked = false;
      await _settings.setBiometricEnabled(value: false);
    }
    notifyListeners();
  }

  /// Shows the biometric prompt and unlocks the app on success.
  Future<bool> unlock() async {
    if (!_locked) return true;
    if (_authenticating) return false;
    _authenticating = true;
    notifyListeners();
    final bool ok = await _biometrics.authenticate(reason: AppStrings.unlockReason);
    _authenticating = false;
    if (ok) _locked = false;
    notifyListeners();
    return ok;
  }

  /// Ask for biometrics before enabling the lock so the user cannot lock
  /// themselves out with an unenrolled sensor.
  Future<bool> setBiometricEnabled({required bool value}) async {
    if (value) {
      final bool ok = await _biometrics.authenticate(reason: 'Confirm to enable biometric unlock');
      if (!ok) return false;
    }
    _biometricEnabled = value;
    await _settings.setBiometricEnabled(value: value);
    notifyListeners();
    return true;
  }

  Future<void> setRememberLogin({required bool value}) async {
    _rememberLogin = value;
    await _settings.setRememberLogin(value: value);
    if (!value) {
      _autoLogin = false;
      await _settings.setAutoLogin(value: false);
      await _auth.clear();
      _hasSavedCredentials = false;
    }
    notifyListeners();
  }

  Future<void> setAutoLogin({required bool value}) async {
    _autoLogin = value && _rememberLogin;
    await _settings.setAutoLogin(value: _autoLogin);
    notifyListeners();
  }

  /// Called by the JS bridge when the user submits the website login form.
  Future<void> onLoginSubmitted(String username, String password) async {
    if (!_rememberLogin || username.trim().isEmpty || password.isEmpty) return;
    await _auth.save(SavedCredentials(username: username.trim(), password: password));
    _hasSavedCredentials = true;
    notifyListeners();
  }

  /// Credentials for automatic sign-in, or `null` when auto login is off or
  /// the app is still locked.
  Future<SavedCredentials?> credentialsForAutoLogin() async {
    if (!_autoLogin || !_rememberLogin || _locked) return null;
    return _auth.read();
  }

  /// Website login failed with the stored password: forget it.
  Future<void> onAutoLoginRejected() async {
    await _auth.clear();
    _hasSavedCredentials = false;
    notifyListeners();
  }

  Future<void> logout() async {
    await _auth.clear();
    await _webSession.clearSession();
    await _oneSignal.logout();
    _hasSavedCredentials = false;
    notifyListeners();
  }

  void onAppBackgrounded() => _backgroundedAt = DateTime.now();

  void onAppResumed() {
    final DateTime? since = _backgroundedAt;
    _backgroundedAt = null;
    if (_biometricEnabled && since != null && DateTime.now().difference(since) >= relockAfter) {
      _locked = true;
      notifyListeners();
    }
  }
}
