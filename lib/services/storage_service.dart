import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wraps plain preferences (non-sensitive settings) and the Android Keystore
/// backed secure storage (credentials, tokens).
class StorageService {
  StorageService._(this._prefs, this._secure);

  static Future<StorageService> create() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    const FlutterSecureStorage secure = FlutterSecureStorage(
      aOptions: AndroidOptions(storageNamespace: 'nexus_secure_store'),
    );
    return StorageService._(prefs, secure);
  }

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  // ---- Plain preferences -----------------------------------------------------
  String? getString(String key) => _prefs.getString(key);

  bool getBool(String key, {bool defaultValue = false}) => _prefs.getBool(key) ?? defaultValue;

  Future<void> setString(String key, String value) => _prefs.setString(key, value);

  Future<void> setBool(String key, {required bool value}) => _prefs.setBool(key, value);

  Future<void> remove(String key) => _prefs.remove(key);

  /// Re-reads values written by another isolate (e.g. the FCM background handler).
  Future<void> reload() => _prefs.reload();

  // ---- Encrypted storage -------------------------------------------------------
  Future<String?> readSecure(String key) async {
    try {
      return await _secure.read(key: key);
    } on Exception {
      // Keystore entries become unreadable after a device-credential reset;
      // treat as missing so the user simply signs in again.
      return null;
    }
  }

  Future<void> writeSecure(String key, String value) => _secure.write(key: key, value: value);

  Future<void> deleteSecure(String key) => _secure.delete(key: key);
}
