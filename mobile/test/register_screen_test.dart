import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forma/core/theme.dart';
import 'package:forma/core/providers.dart';
import 'package:forma/l10n/app_localizations.dart';
import 'package:forma/modules/auth/screens/register_screen.dart';
import 'package:forma/modules/auth/notifiers/auth_state.dart';
import 'package:forma/modules/auth/repositories/auth_repository.dart';

void main() {
  FlutterSecureStorage.setMockInitialValues({});
  Widget buildRegisterScreen({Locale locale = const Locale('en')}) {
    return ProviderScope(
      overrides: [
        localeProvider.overrideWith((ref) => locale),
        numeralSystemProvider.overrideWith((ref) => locale.languageCode == 'ar' ? 'eastern_arabic' : 'western'),
        authStateProvider.overrideWith((ref) => AuthNotifier(ref, ref.watch(authRepositoryProvider))
          ..state = const AuthState(status: AuthStatus.unauthenticated)),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: FormaTheme.darkTheme(locale),
        home: const RegisterScreen(),
      ),
    );
  }

  group('RegisterScreen Layout and Responsive Tests', () {
    const screenSizes = [
      Size(320, 568), // Ultra-compact screen
      Size(360, 640), // Standard Android
      Size(390, 844), // iPhone 12/13/14
    ];

    for (final size in screenSizes) {
      testWidgets('RegisterScreen renders without overflow at ${size.width}x${size.height} in English', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildRegisterScreen(locale: const Locale('en')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('register_email_field')), findsOneWidget);
        expect(find.byKey(const Key('register_password_field')), findsOneWidget);
        expect(find.byKey(const Key('register_dob_field')), findsOneWidget);
        expect(find.byKey(const Key('register_height_field')), findsOneWidget);
        expect(find.byKey(const Key('register_sex_dropdown')), findsOneWidget);
        expect(find.byKey(const Key('register_submit_button')), findsOneWidget);
      });

      testWidgets('RegisterScreen renders without overflow at ${size.width}x${size.height} in Arabic (RTL)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildRegisterScreen(locale: const Locale('ar')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('register_email_field')), findsOneWidget);
        expect(find.byKey(const Key('register_password_field')), findsOneWidget);
        expect(find.byKey(const Key('register_dob_field')), findsOneWidget);
        expect(find.byKey(const Key('register_height_field')), findsOneWidget);
        expect(find.byKey(const Key('register_sex_dropdown')), findsOneWidget);
        expect(find.byKey(const Key('register_submit_button')), findsOneWidget);
      });
    }

    testWidgets('Sex dropdown can be tapped and options selected without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildRegisterScreen(locale: const Locale('en')));
      await tester.pumpAndSettle();

      // Tap dropdown to open menu
      await tester.tap(find.byKey(const Key('register_sex_dropdown')));
      await tester.pumpAndSettle();

      // Select 'Female'
      await tester.tap(find.text('Female').last);
      await tester.pumpAndSettle();

      expect(find.text('Female'), findsOneWidget);
    });

    testWidgets('Date picker button is present and triggers date picker dialog', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildRegisterScreen(locale: const Locale('en')));
      await tester.pumpAndSettle();

      // Tap date picker icon
      await tester.tap(find.byKey(const Key('register_dob_picker_button')));
      await tester.pumpAndSettle();

      // Date picker dialog is shown
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('Form validation shows error messages without layout overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildRegisterScreen(locale: const Locale('en')));
      await tester.pumpAndSettle();

      // Clear fields to force validation errors
      await tester.enterText(find.byKey(const Key('register_dob_field')), 'invalid-date');
      await tester.enterText(find.byKey(const Key('register_height_field')), '30');
      await tester.pumpAndSettle();

      // Scroll to submit button and tap
      await tester.ensureVisible(find.byKey(const Key('register_submit_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Format: YYYY-MM-DD'), findsOneWidget);
      expect(find.text('Height must be between 80 and 260 cm'), findsOneWidget);
    });
  });
}
