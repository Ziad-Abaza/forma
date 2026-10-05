import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forma/core/providers.dart';
import 'package:forma/modules/auth/repositories/auth_repository.dart';
import 'package:forma/modules/auth/notifiers/auth_state.dart';

class MockHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) handler;

  MockHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PreferencesService & Language Persistence Tests', () {
    test('persists and restores locale across restarts', () async {
      // Initially defaults to 'en'
      final initialLocale = await PreferencesService.getSavedLocale();
      expect(initialLocale.languageCode, 'en');

      // Save 'ar'
      await PreferencesService.saveLocale(const Locale('ar'));

      // Retrieve
      final restored = await PreferencesService.getSavedLocale();
      expect(restored.languageCode, 'ar');
    });

    test('persists and restores numeral system across restarts', () async {
      final initialNumeral = await PreferencesService.getSavedNumeralSystem();
      expect(initialNumeral, 'western');

      await PreferencesService.saveNumeralSystem('eastern_arabic');

      final restored = await PreferencesService.getSavedNumeralSystem();
      expect(restored, 'eastern_arabic');
    });
  });

  group('TokenStorage Tests', () {
    test('saves, retrieves, and clears tokens', () async {
      final storage = TokenStorage();

      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);

      await storage.saveTokens(
        accessToken: 'access_123',
        refreshToken: 'refresh_456',
        userId: 'user_789',
        email: 'user@forma.local',
      );

      expect(await storage.getAccessToken(), 'access_123');
      expect(await storage.getRefreshToken(), 'refresh_456');
      expect(await storage.getUserId(), 'user_789');
      expect(await storage.getUserEmail(), 'user@forma.local');

      await storage.clearAll();

      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
      expect(await storage.getUserId(), isNull);
      expect(await storage.getUserEmail(), isNull);
    });
  });

  group('ApiClient Tests', () {
    test('attaches Authorization header and parses successful JSON', () async {
      final storage = TokenStorage();
      await storage.saveTokens(accessToken: 'valid_jwt_token', refreshToken: 'valid_refresh');

      final mockHttp = MockHttpClient((req) async {
        expect(req.headers['Authorization'], 'Bearer valid_jwt_token');
        return http.Response(jsonEncode({'status': 'ok', 'data': 42}), 200);
      });

      final client = ApiClient(
        getBaseUrl: () => 'http://127.0.0.1:3000',
        tokenStorage: storage,
        httpClient: mockHttp,
      );

      final result = await client.get('/api/v1/test');
      expect(result['status'], 'ok');
      expect(result['data'], 42);
    });

    test('automatically refreshes token on 401 response and retries request', () async {
      final storage = TokenStorage();
      await storage.saveTokens(accessToken: 'expired_jwt', refreshToken: 'active_refresh');

      var attempts = 0;
      final mockHttp = MockHttpClient((req) async {
        if (req.url.path == '/api/v1/auth/refresh') {
          return http.Response(
            jsonEncode({
              'tokens': {
                'accessToken': 'new_access_token',
                'refreshToken': 'new_refresh_token',
                'expiresInSeconds': 900,
              },
              'user': {'id': 'uid', 'email': 'a@b.com'},
            }),
            200,
          );
        }

        attempts++;
        if (attempts == 1) {
          return http.Response(jsonEncode({'error': 'Token expired'}), 401);
        } else {
          expect(req.headers['Authorization'], 'Bearer new_access_token');
          return http.Response(jsonEncode({'success': true}), 200);
        }
      });

      final client = ApiClient(
        getBaseUrl: () => 'http://127.0.0.1:3000',
        tokenStorage: storage,
        httpClient: mockHttp,
      );

      final res = await client.get('/api/v1/protected');
      expect(res['success'], true);
      expect(attempts, 2);
      expect(await storage.getAccessToken(), 'new_access_token');
    });
  });

  group('AuthRepository & AuthNotifier Integration Tests', () {
    test('login authenticates user and updates state', () async {
      final storage = TokenStorage();
      final mockHttp = MockHttpClient((req) async {
        if (req.url.path == '/api/v1/auth/login') {
          return http.Response(
            jsonEncode({
              'user': {
                'id': 'd0186716-1fa5-4554-ba5f-b529aa0eb704',
                'email': 'real_user@forma.local',
                'role': 'user',
                'locale': 'ar',
                'numeralSystem': 'eastern_arabic',
                'emailVerified': true,
              },
              'tokens': {
                'accessToken': 'signed_jwt_access',
                'refreshToken': 'signed_refresh_token',
                'expiresInSeconds': 900,
              },
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final client = ApiClient(
        getBaseUrl: () => 'http://localhost:3000',
        tokenStorage: storage,
        httpClient: mockHttp,
      );

      final repo = AuthRepository(apiClient: client, tokenStorage: storage);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );

      final notifier = container.read(authStateProvider.notifier);
      await notifier.login('real_user@forma.local', 'Password123!');

      final state = container.read(authStateProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.user?.email, 'real_user@forma.local');
      expect(state.user?.locale, 'ar');
      expect(container.read(localeProvider).languageCode, 'ar');
      expect(container.read(numeralSystemProvider), 'eastern_arabic');
    });

    test('logout revokes tokens and resets state', () async {
      final storage = TokenStorage();
      await storage.saveTokens(accessToken: 'acc', refreshToken: 'ref');

      var logoutCalled = false;
      final mockHttp = MockHttpClient((req) async {
        if (req.url.path == '/api/v1/auth/logout') {
          logoutCalled = true;
          return http.Response(jsonEncode({'message': 'Logged out'}), 200);
        }
        return http.Response('Not Found', 404);
      });

      final client = ApiClient(
        getBaseUrl: () => 'http://localhost:3000',
        tokenStorage: storage,
        httpClient: mockHttp,
      );

      final repo = AuthRepository(apiClient: client, tokenStorage: storage);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );

      final notifier = container.read(authStateProvider.notifier);
      await notifier.logout();

      expect(logoutCalled, isTrue);
      expect(container.read(authStateProvider).isAuthenticated, isFalse);
      expect(await storage.getAccessToken(), isNull);
    });
  });
}
