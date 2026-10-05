import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Storage service for authentication credentials.
///
/// Tokens are secrets and must never live in plaintext SharedPreferences.
/// Uses platform keychains: iOS Keychain, Android Keystore-backed
/// EncryptedSharedPreferences (explicit — not the default in v9).
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static const _keyAccessToken = 'forma_access_token';
  static const _keyRefreshToken = 'forma_refresh_token';
  static const _keyUserId = 'forma_user_id';
  static const _keyUserEmail = 'forma_user_email';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    String? userId,
    String? email,
  }) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
    if (userId != null) await _storage.write(key: _keyUserId, value: userId);
    if (email != null) await _storage.write(key: _keyUserEmail, value: email);
  }

  Future<String?> getAccessToken() => _storage.read(key: _keyAccessToken);

  Future<String?> getRefreshToken() => _storage.read(key: _keyRefreshToken);

  Future<String?> getUserId() => _storage.read(key: _keyUserId);

  Future<String?> getUserEmail() => _storage.read(key: _keyUserEmail);

  Future<void> clearAll() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyUserEmail);
  }
}
