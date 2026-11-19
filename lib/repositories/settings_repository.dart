import 'package:material_ui/material_ui.dart';

import '../constants/app_constants.dart';
import '../services/storage_service.dart';

/// User preferences persisted on the device.
class SettingsRepository {
  SettingsRepository(this._storage);

  final StorageService _storage;

  ThemeMode get themeMode => switch (_storage.getString(StorageKeys.themeMode)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> setThemeMode(ThemeMode mode) =>
      _storage.setString(StorageKeys.themeMode, mode.name);

  bool get biometricEnabled => _storage.getBool(StorageKeys.biometricEnabled);

  Future<void> setBiometricEnabled({required bool value}) =>
      _storage.setBool(StorageKeys.biometricEnabled, value: value);

  bool get rememberLogin => _storage.getBool(StorageKeys.rememberLogin, defaultValue: true);

  Future<void> setRememberLogin({required bool value}) =>
      _storage.setBool(StorageKeys.rememberLogin, value: value);

  bool get autoLogin => _storage.getBool(StorageKeys.autoLogin, defaultValue: true);

  Future<void> setAutoLogin({required bool value}) =>
      _storage.setBool(StorageKeys.autoLogin, value: value);

  bool get permissionsAsked => _storage.getBool(StorageKeys.onboardingPermissionsAsked);

  Future<void> setPermissionsAsked() =>
      _storage.setBool(StorageKeys.onboardingPermissionsAsked, value: true);

  String? get referralCode => _storage.getString(StorageKeys.referralCode);

  Future<void> setReferralCode(String? code) => code == null || code.isEmpty
      ? _storage.remove(StorageKeys.referralCode)
      : _storage.setString(StorageKeys.referralCode, code);

  String? get skippedVersion => _storage.getString(StorageKeys.skippedVersion);

  Future<void> setSkippedVersion(String version) =>
      _storage.setString(StorageKeys.skippedVersion, version);
}
