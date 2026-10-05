import 'package:shared_preferences/shared_preferences.dart';

/// Storage service for persistent authentication credentials.
/// Uses SharedPreferences for token and session persistence.
class TokenStorage {
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, accessToken);
    await prefs.setString(_keyRefreshToken, refreshToken);
    if (userId != null) await prefs.setString(_keyUserId, userId);
    if (email != null) await prefs.setString(_keyUserEmail, email);
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccessToken);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRefreshToken);
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserEmail);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserEmail);
  }
}
