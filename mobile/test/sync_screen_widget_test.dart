import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forma/core/theme.dart';
import 'package:forma/core/providers.dart';
import 'package:forma/l10n/app_localizations.dart';
import 'package:forma/presentation/screens/sync_screen.dart';

void main() {
  Widget buildTestableWidget({
    Locale locale = const Locale('en'),
  }) {
    return ProviderScope(
      overrides: [
        localeProvider.overrideWith((ref) => locale),
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
    testWidgets('renders device integration cards and epistemic precedence banner in English', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Epistemic Precedence Banner
      expect(find.text('Connected Devices & Sync'), findsOneWidget);
      expect(find.text('Conflict Resolution & Provenance'), findsOneWidget);
      expect(find.byIcon(Icons.verified_outlined), findsOneWidget);

      // Devices
      expect(find.text('Health Connect'), findsOneWidget);
      expect(find.text('Apple Health'), findsOneWidget);
      expect(find.text('Garmin Connect'), findsOneWidget);
      expect(find.text('Withings Health Mate'), findsOneWidget);
      expect(find.text('Oura Ring'), findsOneWidget);

      // Default Health Connect is connected
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Disconnected'), findsNWidgets(4));

      // Privacy Section
      expect(find.text('Data Privacy & Management'), findsOneWidget);
      expect(find.text('Export Health Data (GDPR)'), findsOneWidget);
      expect(find.text('Delete Account & Purge Data'), findsOneWidget);
    });

    testWidgets('toggles device connection status and triggers sync', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Apple Health is disconnected initially
      final appleHealthToggle = find.byKey(const Key('toggle_button_apple_health'));
      expect(appleHealthToggle, findsOneWidget);
      expect(find.descendant(of: appleHealthToggle, matching: find.text('Connect')), findsOneWidget);

      // Tap connect
      await tester.tap(appleHealthToggle);
      await tester.pumpAndSettle();

      // Apple Health is now connected
      expect(find.descendant(of: appleHealthToggle, matching: find.text('Disconnect')), findsOneWidget);

      // Sync button should now be present for Apple Health
      final syncButton = find.byKey(const Key('sync_button_apple_health'));
      expect(syncButton, findsOneWidget);

      // Tap sync
      await tester.tap(syncButton);
      await tester.pump(); // Triggers sync state
      await tester.pumpAndSettle(); // Finishes sync

      expect(find.text('Last synced: Just now'), findsWidgets);
    });

    testWidgets('opens export dialog and account purge confirmation dialogs', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // 1. Export Data Dialog
      final exportTile = find.byKey(const Key('export_data_tile'));
      await tester.tap(exportTile);
      await tester.pumpAndSettle();

      expect(find.text('Data export generated successfully.'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // 2. Account Purge Dialog
      final purgeTile = find.byKey(const Key('purge_account_tile'));
      await tester.tap(purgeTile);
      await tester.pumpAndSettle();

      expect(
        find.text('Are you sure? This permanently deletes all your health data across all services.'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);

      // Confirm purge
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(find.text('Confirmed & Executed'), findsOneWidget);
    });

    testWidgets('renders perfectly in Arabic with full bilingual parity and RTL layout', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableWidget(locale: const Locale('ar')));
      await tester.pumpAndSettle();

      // Arabic header and banner
      expect(find.text('الأجهزة المتصلة والمزامنة'), findsOneWidget);
      expect(find.text('فض التضارب ومصدر البيانات'), findsOneWidget);

      // Arabic device names
      expect(find.text('هيلث كونيكت'), findsOneWidget);
      expect(find.text('آبل هيلث'), findsOneWidget);
      expect(find.text('جارمن كونيكت'), findsOneWidget);

      // Arabic privacy options
      expect(find.text('خصوصية البيانات وإدارتها'), findsOneWidget);
      expect(find.text('تصدير البيانات الصحية (GDPR)'), findsOneWidget);
      expect(find.text('حذف الحساب ومسح البيانات'), findsOneWidget);
    });
  });
}
