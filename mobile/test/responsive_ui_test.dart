import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forma/core/theme.dart';
import 'package:forma/core/providers.dart';
import 'package:forma/l10n/app_localizations.dart';
import 'package:forma/presentation/screens/dashboard_screen.dart';
import 'package:forma/presentation/screens/sync_screen.dart';

void main() {
  Widget buildDashboard({Locale locale = const Locale('en')}) {
    return ProviderScope(
      overrides: [
        localeProvider.overrideWith((ref) => locale),
        numeralSystemProvider.overrideWith((ref) => locale.languageCode == 'ar' ? 'eastern_arabic' : 'western'),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: FormaTheme.darkTheme(locale),
        home: const DashboardScreen(),
      ),
    );
  }

  Widget buildSyncScreen({Locale locale = const Locale('en')}) {
    return ProviderScope(
      overrides: [
        localeProvider.overrideWith((ref) => locale),
        numeralSystemProvider.overrideWith((ref) => locale.languageCode == 'ar' ? 'eastern_arabic' : 'western'),
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

  group('Responsive Layout Tests - Dashboard Screen', () {
    const screenSizes = [
      Size(320, 568), // Ultra-compact screen
      Size(360, 640), // Standard compact Android
      Size(390, 844), // Modern iPhone standard
    ];

    for (final size in screenSizes) {
      testWidgets('DashboardScreen renders without overflow at ${size.width}x${size.height} in English', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildDashboard(locale: const Locale('en')));
        await tester.pumpAndSettle();

        // Verify AppBar title and actions are rendered
        expect(find.text('Forma'), findsOneWidget);
        expect(find.byKey(const Key('sync_devices_button')), findsOneWidget);
        expect(find.byKey(const Key('language_toggle_button')), findsOneWidget);

        // Verify Trends card filters can scroll horizontally
        expect(find.text('Trends & Trajectory'), findsOneWidget);
        expect(find.text('7D'), findsOneWidget);
        expect(find.text('30D'), findsOneWidget);
        expect(find.text('90D'), findsOneWidget);
        expect(find.text('1Y'), findsOneWidget);

        // Scroll main view so Trends card is centered
        await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -100));
        await tester.pumpAndSettle();

        // Drag horizontal filter chips
        await tester.drag(find.text('7D'), const Offset(-50, 0), warnIfMissed: false);
        await tester.pumpAndSettle();

        // Scroll down to verify Energy & Nutrition Targets Card
        await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -200));
        await tester.pumpAndSettle();
        expect(find.text('Energy & Nutrition Targets'), findsOneWidget);
        expect(find.text('Protein'), findsOneWidget);
      });

      testWidgets('DashboardScreen renders without overflow at ${size.width}x${size.height} in Arabic (RTL)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildDashboard(locale: const Locale('ar')));
        await tester.pumpAndSettle();

        // Verify Arabic elements
        expect(find.text('فورما'), findsOneWidget);
        expect(find.text('المسار والاتجاهات'), findsOneWidget);
        expect(find.text('أهداف الطاقة والتغذية'), findsOneWidget);
      });
    }
  });

  group('Responsive Layout Tests - Connected Devices Screen', () {
    const screenSizes = [
      Size(320, 568), // Ultra-compact screen
      Size(360, 640), // Standard compact Android
      Size(390, 844), // Modern iPhone standard
    ];

    for (final size in screenSizes) {
      testWidgets('SyncScreen renders connected device list without overflow at ${size.width}x${size.height} in English', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildSyncScreen(locale: const Locale('en')));
        await tester.pumpAndSettle();

        // Verify device list items
        expect(find.text('Health Connect'), findsOneWidget);
        expect(find.text('Connected'), findsOneWidget);
        expect(find.text('Last synced: 10 mins ago'), findsOneWidget);

        // Scroll list if needed to tap toggle button
        final appleHealthToggle = find.byKey(const Key('toggle_button_apple_health'));
        await tester.drag(find.byType(ListView), const Offset(0, -150));
        await tester.pumpAndSettle();

        expect(appleHealthToggle, findsOneWidget);
        await tester.tap(appleHealthToggle, warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(find.descendant(of: appleHealthToggle, matching: find.text('Disconnect')), findsOneWidget);
      });

      testWidgets('SyncScreen renders connected device list without overflow at ${size.width}x${size.height} in Arabic (RTL)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildSyncScreen(locale: const Locale('ar')));
        await tester.pumpAndSettle();

        expect(find.text('هيلث كونيكت'), findsOneWidget);
        expect(find.text('متصل'), findsOneWidget);
      });
    }
  });
}
