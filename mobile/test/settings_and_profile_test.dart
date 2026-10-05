import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:forma/core/providers.dart';
import 'package:forma/core/theme.dart';
import 'package:forma/l10n/app_localizations.dart';
import 'package:forma/modules/auth/notifiers/auth_state.dart';
import 'package:forma/modules/auth/models/user_model.dart';
import 'package:forma/modules/auth/repositories/auth_repository.dart';
import 'package:forma/presentation/screens/settings_screen.dart';
import 'package:forma/modules/profile/screens/profile_screen.dart';

class MockHttpForSettings extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;

    if (path.contains('/api/v1/ai/config')) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'activeProvider': 'google',
          'availableProviders': ['google', 'openai', 'anthropic', 'secondary'],
          'models': [
            {
              'id': 'gemini-3.8-flash',
              'provider': 'google',
              'displayName': 'Google Gemini 3.8 Flash',
              'capabilities': ['text', 'vision', 'structured_output', 'tool_calling'],
              'evalStatus': 'approved'
            }
          ],
          'credentials': [
            {
              'id': 'cred-1',
              'provider': 'google',
              'keyFingerprint': '...5678',
              'isActive': true,
              'createdAt': DateTime.now().toIso8601String()
            }
          ]
        }))),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    if (path.contains('/api/v1/ai/test-connection')) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'status': 'success',
          'provider': 'google',
          'message': 'Connection verified'
        }))),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    if (path.contains('/api/v1/ai/credentials')) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'credential': {
            'id': 'cred-new',
            'provider': 'openai',
            'keyFingerprint': '...9999',
            'isActive': true,
            'createdAt': DateTime.now().toIso8601String()
          }
        }))),
        201,
        headers: {'content-type': 'application/json'},
      );
    }

    if (path.contains('/api/v1/profile')) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'userId': 'user-test-123',
          'dateOfBirth': '1995-05-15',
          'sexForCalculation': 'male',
          'heightCm': 180.0,
          'activityLevel': 'moderately_active',
          'experienceLevel': 'intermediate',
          'constraints': [],
          'preferences': {}
        }))),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    if (path.contains('/api/v1/privacy/export')) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'user': {'id': 'user-test-123', 'email': 'test@forma.local'},
          'modules': {'measurements': [], 'goals': []}
        }))),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({'status': 'ok'}))),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsScreen Widget & Feature Integration Tests', () {
    testWidgets('renders SettingsScreen with AI config, Profile navigation, and Privacy controls', (tester) async {
      final mockClient = MockHttpForSettings();
      final storage = TokenStorage();
      await storage.saveTokens(
        accessToken: 'valid-test-token',
        refreshToken: 'valid-refresh-token',
        userId: 'user-test-123',
        email: 'test@forma.local',
      );

      final apiClient = ApiClient(
        getBaseUrl: () => 'http://localhost:3000',
        tokenStorage: storage,
        httpClient: mockClient,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStorageProvider.overrideWithValue(storage),
            apiClientProvider.overrideWithValue(apiClient),
            authStateProvider.overrideWith((ref) {
              return AuthNotifier(ref, ref.watch(authRepositoryProvider))
                ..state = const AuthState(
                  status: AuthStatus.authenticated,
                  user: UserModel(
                    id: 'user-test-123',
                    email: 'test@forma.local',
                    role: 'user',
                    locale: 'en',
                    numeralSystem: 'western',
                    emailVerified: true,
                  ),
                );
            }),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: FormaTheme.darkTheme(const Locale('en')),
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify core sections render
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('AI Companion & Provider Configuration'), findsOneWidget);
      expect(find.text('Privacy & Data Ownership'), findsOneWidget);
      expect(find.byKey(const Key('byok_api_key_field')), findsOneWidget);
      expect(find.byKey(const Key('test_ai_connection_button')), findsOneWidget);
      expect(find.byKey(const Key('save_ai_key_button')), findsOneWidget);
      expect(find.byKey(const Key('settings_export_button')), findsOneWidget);
      expect(find.byKey(const Key('settings_delete_account_button')), findsOneWidget);

      // Verify stored credential badge
      expect(find.text('Fingerprint: ...5678 (AES-256-GCM)'), findsOneWidget);

      // Test connection button tap
      await tester.scrollUntilVisible(
        find.byKey(const Key('test_ai_connection_button')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('test_ai_connection_button')));
      await tester.pumpAndSettle();
      expect(find.textContaining('verified successfully'), findsOneWidget);

      // Open Export dialog
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings_export_button')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('settings_export_button')));
      await tester.pumpAndSettle();
      expect(find.text('Copy JSON'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });

    testWidgets('renders ProfileScreen and allows saving updated height and parameters', (tester) async {
      final mockClient = MockHttpForSettings();
      final storage = TokenStorage();
      await storage.saveTokens(
        accessToken: 'valid-test-token',
        refreshToken: 'valid-refresh-token',
        userId: 'user-test-123',
        email: 'test@forma.local',
      );

      final apiClient = ApiClient(
        getBaseUrl: () => 'http://localhost:3000',
        tokenStorage: storage,
        httpClient: mockClient,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStorageProvider.overrideWithValue(storage),
            apiClientProvider.overrideWithValue(apiClient),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: FormaTheme.darkTheme(const Locale('en')),
            home: const ProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsWidgets);
      expect(find.byKey(const Key('profile_height_field')), findsOneWidget);
      expect(find.byKey(const Key('profile_sex_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('profile_activity_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('profile_save_button')), findsOneWidget);

      // Change height
      await tester.enterText(find.byKey(const Key('profile_height_field')), '182');
      await tester.tap(find.byKey(const Key('profile_save_button')));
      await tester.pumpAndSettle();

      expect(find.text('Profile updated successfully'), findsOneWidget);
    });

    testWidgets('renders SettingsScreen in Arabic RTL without error or overflow', (tester) async {
      final mockClient = MockHttpForSettings();
      final storage = TokenStorage();
      await storage.saveTokens(
        accessToken: 'valid-test-token',
        refreshToken: 'valid-refresh-token',
        userId: 'user-test-123',
        email: 'test@forma.local',
      );

      final apiClient = ApiClient(
        getBaseUrl: () => 'http://localhost:3000',
        tokenStorage: storage,
        httpClient: mockClient,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStorageProvider.overrideWithValue(storage),
            apiClientProvider.overrideWithValue(apiClient),
            localeProvider.overrideWith((ref) => const Locale('ar')),
            numeralSystemProvider.overrideWith((ref) => 'eastern_arabic'),
            authStateProvider.overrideWith((ref) {
              return AuthNotifier(ref, ref.watch(authRepositoryProvider))
                ..state = const AuthState(
                  status: AuthStatus.authenticated,
                  user: UserModel(
                    id: 'user-test-123',
                    email: 'test@forma.local',
                    role: 'user',
                    locale: 'ar',
                    numeralSystem: 'eastern_arabic',
                    emailVerified: true,
                  ),
                );
            }),
          ],
          child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: FormaTheme.darkTheme(const Locale('ar')),
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('الإعدادات'), findsOneWidget);
      expect(find.text('الملف الشخصي'), findsOneWidget);
      expect(find.text('الخصوصية وملكية البيانات'), findsOneWidget);
    });

    testWidgets('renders SettingsScreen on narrow 320px screen in Arabic RTL without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockClient = MockHttpForSettings();
      final storage = TokenStorage();
      await storage.saveTokens(
        accessToken: 'valid-test-token',
        refreshToken: 'valid-refresh-token',
        userId: 'user-test-123',
        email: 'test@forma.local',
      );

      final apiClient = ApiClient(
        getBaseUrl: () => 'http://localhost:3000',
        tokenStorage: storage,
        httpClient: mockClient,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStorageProvider.overrideWithValue(storage),
            apiClientProvider.overrideWithValue(apiClient),
            localeProvider.overrideWith((ref) => const Locale('ar')),
            numeralSystemProvider.overrideWith((ref) => 'eastern_arabic'),
            authStateProvider.overrideWith((ref) {
              return AuthNotifier(ref, ref.watch(authRepositoryProvider))
                ..state = const AuthState(
                  status: AuthStatus.authenticated,
                  user: UserModel(
                    id: 'user-test-123',
                    email: 'test@forma.local',
                    role: 'user',
                    locale: 'ar',
                    numeralSystem: 'eastern_arabic',
                    emailVerified: true,
                  ),
                );
            }),
          ],
          child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: FormaTheme.darkTheme(const Locale('ar')),
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
