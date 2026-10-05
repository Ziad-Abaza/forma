import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../models/session_model.dart';
import '../models/user_model.dart';

class AuthRepository {
  final ApiClient apiClient;
  final TokenStorage tokenStorage;

  AuthRepository({
    required this.apiClient,
    required this.tokenStorage,
  });

  Future<UserModel> register({
    required String email,
    required String password,
    required String dateOfBirth,
    required double heightCm,
    String sexForCalculation = 'unspecified',
    String locale = 'en',
    String numeralSystem = 'western',
    required bool termsConsent,
    required bool healthConsent,
    required bool aiConsent,
  }) async {
    final body = {
      'email': email.trim(),
      'password': password,
      'dateOfBirth': dateOfBirth,
      'heightCm': heightCm,
      'sexForCalculation': sexForCalculation,
      'locale': locale,
      'numeralSystem': numeralSystem,
      'consents': {
        'termsOfService': termsConsent,
        'healthDataProcessing': healthConsent,
        'aiThirdPartyProcessing': aiConsent,
      },
    };

    final resp = await apiClient.post('/api/v1/auth/register', body: body, requireAuth: false);
    final authResp = AuthResponseModel.fromJson(resp as Map<String, dynamic>);

    await tokenStorage.saveTokens(
      accessToken: authResp.accessToken,
      refreshToken: authResp.refreshToken,
      userId: authResp.user.id,
      email: authResp.user.email,
    );

    return authResp.user;
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final body = {
      'email': email.trim(),
      'password': password,
      'deviceInfo': {'platform': 'mobile'},
    };

    final resp = await apiClient.post('/api/v1/auth/login', body: body, requireAuth: false);
    final authResp = AuthResponseModel.fromJson(resp as Map<String, dynamic>);

    await tokenStorage.saveTokens(
      accessToken: authResp.accessToken,
      refreshToken: authResp.refreshToken,
      userId: authResp.user.id,
      email: authResp.user.email,
    );

    return authResp.user;
  }

  /// Returns the authenticated user, null only when there is no session
  /// (no token, or the server rejected it with 401). Network/server errors
  /// propagate so callers can distinguish "logged out" from "unreachable".
  Future<UserModel?> getCurrentUser() async {
    final token = await tokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return null;

    try {
      final resp = await apiClient.get('/api/v1/auth/me');
      if (resp is Map<String, dynamic>) {
        return UserModel.fromJson(resp);
      }
      return null;
    } on ApiException catch (e) {
      if (e.statusCode == 401) return null; // session truly invalid
      rethrow; // server-side failure — not "no session"
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken = await tokenStorage.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await apiClient.post(
          '/api/v1/auth/logout',
          body: {'refreshToken': refreshToken},
          requireAuth: false,
        );
      }
    } catch (_) {} finally {
      await tokenStorage.clearAll();
    }
  }

  /// Lists the user's sessions (refresh-token families) for device management.
  Future<List<SessionInfo>> listSessions() async {
    final resp = await apiClient.get('/api/v1/auth/sessions');
    if (resp is Map<String, dynamic>) {
      final raw = resp['sessions'] as List<dynamic>? ?? const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(SessionInfo.fromJson)
          .toList();
    }
    return const [];
  }

  /// Revokes a single session by id. Throws ApiException(404) when the
  /// session does not belong to the current user.
  Future<void> revokeSession(String sessionId) async {
    await apiClient.delete('/api/v1/auth/sessions/$sessionId');
  }

  /// Revokes every session for the user. On success the backend has
  /// invalidated all refresh-token families — the next authenticated
  /// request will surface the session-expired path and route to login.
  /// Returns the number of sessions revoked when reported by the server.
  Future<int?> logoutAll() async {
    final resp = await apiClient.post('/api/v1/auth/logout-all', body: const {});
    if (resp is Map<String, dynamic>) {
      return (resp['sessionsRevoked'] as num?)?.toInt();
    }
    return null;
  }

  /// Changes the account password. On success the backend revokes ALL
  /// sessions, so the user will be logged out via the ApiClient
  /// session-expired path. Returns the server-provided message when present.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final resp = await apiClient.post('/api/v1/auth/change-password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
    if (resp is Map<String, dynamic>) {
      return resp['message']?.toString();
    }
    return null;
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final tokenStorage = ref.watch(tokenStorageProvider);
  return AuthRepository(apiClient: apiClient, tokenStorage: tokenStorage);
});

/// Live list of the user's sessions for the settings/device-management UI.
final sessionsProvider = FutureProvider.autoDispose<List<SessionInfo>>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return await repo.listSessions();
});
