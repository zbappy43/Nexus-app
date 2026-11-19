import '../constants/app_constants.dart';
import '../services/storage_service.dart';

/// Website login credentials captured from the login form.
class SavedCredentials {
  const SavedCredentials({required this.username, required this.password});

  final String username;
  final String password;
}

/// Stores website credentials encrypted with the Android Keystore
/// (`flutter_secure_storage`, AES-GCM). Used for "Remember login" and
/// "Auto login"; access can additionally be gated behind biometrics.
class AuthRepository {
  AuthRepository(this._storage);

  final StorageService _storage;

  Future<SavedCredentials?> read() async {
    final String? username = await _storage.readSecure(StorageKeys.secureUsername);
    final String? password = await _storage.readSecure(StorageKeys.securePassword);
    if (username == null || username.isEmpty || password == null || password.isEmpty) {
      return null;
    }
    return SavedCredentials(username: username, password: password);
  }

  Future<bool> hasCredentials() async => (await read()) != null;

  Future<void> save(SavedCredentials credentials) async {
    await _storage.writeSecure(StorageKeys.secureUsername, credentials.username);
    await _storage.writeSecure(StorageKeys.securePassword, credentials.password);
  }

  Future<void> clear() async {
    await _storage.deleteSecure(StorageKeys.secureUsername);
    await _storage.deleteSecure(StorageKeys.securePassword);
  }
}
