import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
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

  Future<UserModel?> getCurrentUser() async {
    final token = await tokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return null;

    try {
      final resp = await apiClient.get('/api/v1/auth/me');
      if (resp is Map<String, dynamic>) {
        return UserModel.fromJson(resp);
      }
      return null;
    } catch (_) {
      return null;
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
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final tokenStorage = ref.watch(tokenStorageProvider);
  return AuthRepository(apiClient: apiClient, tokenStorage: tokenStorage);
});
