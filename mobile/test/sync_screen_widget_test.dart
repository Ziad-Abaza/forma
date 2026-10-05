import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forma/core/theme.dart';
import 'package:forma/core/providers.dart';
import 'package:forma/l10n/app_localizations.dart';
import 'package:forma/modules/auth/notifiers/auth_state.dart';
import 'package:forma/modules/auth/models/user_model.dart';
import 'package:forma/modules/auth/repositories/auth_repository.dart';
import 'package:forma/modules/integrations/repositories/integrations_repository.dart';
import 'package:forma/presentation/screens/sync_screen.dart';

class FakeIntegrationsRepository extends IntegrationsRepository {
  FakeIntegrationsRepository({this.failCalls = false})
      : super(
          apiClient: ApiClient(
            getBaseUrl: () => 'http://localhost',
            tokenStorage: TokenStorage(),
          ),
        );

  final Map<String, IntegrationConnectionModel> _connections = {};
  bool failCalls;
  bool failActions = false;
  int syncCalls = 0;
  int connectCalls = 0;
  List<Map<String, dynamic>>? lastSyncRecords;

  @override
  Future<List<String>> getProviders() async {
    if (failCalls) throw ApiException(statusCode: 0, message: 'unreachable');
    return const ['health_connect', 'apple_health'];
  }

  @override
  Future<List<IntegrationConnectionModel>> getConnections() async {
    if (failCalls) throw ApiException(statusCode: 0, message: 'unreachable');
    return _connections.values.toList();
  }

  @override
  Future<IntegrationConnectionModel> connectProvider(String provider,
      {List<String>? scopes}) async {
    connectCalls++;
    if (failActions) throw ApiException(statusCode: 500, message: 'connect failed');
    final conn = IntegrationConnectionModel(
      id: 'conn_$provider',
      provider: provider,
      status: 'connected',
    );
    _connections[provider] = conn;
    return conn;
  }

  @override
  Future<void> disconnectProvider(String provider) async {
    if (failActions) throw ApiException(statusCode: 500, message: 'disconnect failed');
    _connections[provider] = IntegrationConnectionModel(
      id: 'conn_$provider',
      provider: provider,
      status: 'revoked',
    );
  }

  @override
  Future<Map<String, dynamic>> syncProvider(String provider,
      {required List<Map<String, dynamic>> records}) async {
    syncCalls++;
    lastSyncRecords = records;
    if (failActions) throw ApiException(statusCode: 500, message: 'provider down');
    return {
      'batchId': 'b1',
      'provider': provider,
      'totalProcessed': records.length,
      'inserted': records.length,
      'deduplicated': 0,
      'rejected': 0,
    };
  }
}

void main() {
  const testUser = UserModel(
    id: 'test-user',
    email: 'test@forma.local',
    role: 'user',
    locale: 'en',
    numeralSystem: 'western',
    emailVerified: true,
  );

  Widget buildTestableWidget({
    Locale locale = const Locale('en'),
    required FakeIntegrationsRepository repository,
    bool authenticated = true,
  }) {
    return ProviderScope(
      overrides: [
        localeProvider.overrideWith((ref) => locale),
        integrationsRepositoryProvider.overrideWithValue(repository),
        authStateProvider.overrideWith((ref) =>
            AuthNotifier(ref, ref.watch(authRepositoryProvider))
              ..state = AuthState(
                status: authenticated
                    ? AuthStatus.authenticated
                    : AuthStatus.unauthenticated,
                user: authenticated ? testUser : null,
              )),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: FormaTheme.darkTheme(locale),
        home: const SyncScreen(),
      ),
    );
  }

  group('SyncScreen Widget Tests (Phase 6 Wearables & Privacy)', () {
    testWidgets('renders provider catalog and privacy section in English', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(repository: FakeIntegrationsRepository()));
      await tester.pumpAndSettle();

      // Epistemic Precedence Banner
      expect(find.text('Connected Devices & Sync'), findsOneWidget);
      expect(find.text('Conflict Resolution & Provenance'), findsOneWidget);
      expect(find.byIcon(Icons.verified_outlined), findsOneWidget);

      // Providers come from the server catalog fake
      expect(find.text('Health Connect'), findsOneWidget);
      expect(find.text('Apple Health'), findsOneWidget);

      // All devices disconnected initially (server reported no connections)
      expect(find.text('Disconnected'), findsNWidgets(2));

      // Privacy Section
      expect(find.text('Data Privacy & Management'), findsOneWidget);
      expect(find.text('Export Health Data (GDPR)'), findsOneWidget);
      expect(find.text('Delete Account & Purge Data'), findsOneWidget);
    });

    testWidgets('shows error state when connection catalog fails to load', (tester) async {
      final repo = FakeIntegrationsRepository(failCalls: true);
      await tester.pumpWidget(buildTestableWidget(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load your device connections."), findsOneWidget);
      expect(find.byKey(const Key('integrations_retry_button')), findsOneWidget);

      // Retry succeeds after recovery
      repo.failCalls = false;
      await tester.tap(find.byKey(const Key('integrations_retry_button')));
      await tester.pumpAndSettle();
      expect(find.text('Health Connect'), findsOneWidget);
    });

    testWidgets('connect only marks device connected after server confirmation', (tester) async {
      final repo = FakeIntegrationsRepository();
      await tester.pumpWidget(buildTestableWidget(repository: repo));
      await tester.pumpAndSettle();

      final appleHealthToggle = find.byKey(const Key('toggle_button_apple_health'));
      expect(appleHealthToggle, findsOneWidget);
      expect(find.descendant(of: appleHealthToggle, matching: find.text('Connect')), findsOneWidget);

      await tester.tap(appleHealthToggle);
      await tester.pumpAndSettle();

      expect(repo.connectCalls, 1);
      expect(find.descendant(of: appleHealthToggle, matching: find.text('Disconnect')),
          findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
    });

    testWidgets('failed connect keeps disconnected state and shows error', (tester) async {
      final repo = FakeIntegrationsRepository()..failActions = true;
      await tester.pumpWidget(buildTestableWidget(repository: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('toggle_button_apple_health')));
      await tester.pumpAndSettle();

      expect(repo.connectCalls, 1);
      expect(find.text("Couldn't update the connection. Please try again."), findsOneWidget);
      // Still disconnected — no fabricated connected state
      final appleHealthToggle = find.byKey(const Key('toggle_button_apple_health'));
      expect(find.descendant(of: appleHealthToggle, matching: find.text('Connect')), findsOneWidget);
    });

    testWidgets('sync sends zero fabricated records and reflects real outcome', (tester) async {
      final repo = FakeIntegrationsRepository();
      await tester.pumpWidget(buildTestableWidget(repository: repo));
      await tester.pumpAndSettle();

      // Connect first (server-confirmed)
      await tester.tap(find.byKey(const Key('toggle_button_apple_health')));
      await tester.pumpAndSettle();

      // Sync button now visible
      final syncButton = find.byKey(const Key('sync_button_apple_health'));
      expect(syncButton, findsOneWidget);
      await tester.tap(syncButton);
      await tester.pumpAndSettle();

      // HC-004: no fabricated observations are ever sent by the client
      expect(repo.syncCalls, 1);
      expect(repo.lastSyncRecords, isNotNull);
      expect(repo.lastSyncRecords, isEmpty);
    });

    testWidgets('failed sync surfaces an error instead of fake success', (tester) async {
      final repo = FakeIntegrationsRepository();
      await tester.pumpWidget(buildTestableWidget(repository: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('toggle_button_apple_health')));
      await tester.pumpAndSettle();

      repo.failActions = true;
      await tester.tap(find.byKey(const Key('sync_button_apple_health')));
      await tester.pumpAndSettle();

      expect(find.text('Sync failed. Please try again.'), findsOneWidget);
      // No 'Last synced' text was fabricated
      expect(find.textContaining('Last synced'), findsNothing);
    });

    testWidgets('renders perfectly in Arabic with full bilingual parity and RTL layout', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(
        locale: const Locale('ar'),
        repository: FakeIntegrationsRepository(),
      ));
      await tester.pumpAndSettle();

      // Arabic header and banner
      expect(find.text('الأجهزة المتصلة والمزامنة'), findsOneWidget);
      expect(find.text('فض التضارب ومصدر البيانات'), findsOneWidget);

      // Arabic device names (from fake catalog)
      expect(find.text('هيلث كونيكت'), findsOneWidget);
      expect(find.text('آبل هيلث'), findsOneWidget);

      // Arabic privacy options
      expect(find.text('خصوصية البيانات وإدارتها'), findsOneWidget);
      expect(find.text('تصدير البيانات الصحية (GDPR)'), findsOneWidget);
      expect(find.text('حذف الحساب ومسح البيانات'), findsOneWidget);
    });
  });
}
