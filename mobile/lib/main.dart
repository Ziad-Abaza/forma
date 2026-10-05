import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n/app_localizations.dart';
import 'core/theme.dart';
import 'core/providers.dart';
import 'modules/auth/notifiers/auth_state.dart';
import 'modules/auth/screens/login_screen.dart';
import 'presentation/screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: FormaTheme.obsidianBackground,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final savedLocale = await PreferencesService.getSavedLocale();
  final savedNumeralSystem = await PreferencesService.getSavedNumeralSystem();

  runApp(
    ProviderScope(
      overrides: [
        localeProvider.overrideWith((ref) => savedLocale),
        numeralSystemProvider.overrideWith((ref) => savedNumeralSystem),
      ],
      child: const FormaApp(),
    ),
  );
}

class FormaApp extends ConsumerWidget {
  const FormaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final authState = ref.watch(authStateProvider);

    Widget homeWidget;
    if (authState.status == AuthStatus.initial ||
        (authState.status == AuthStatus.loading && authState.user == null)) {
      homeWidget = const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: FormaTheme.primaryTeal),
        ),
      );
    } else if (authState.isAuthenticated) {
      homeWidget = const DashboardScreen();
    } else {
      homeWidget = const LoginScreen();
    }

    return MaterialApp(
      title: 'Forma',
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: FormaTheme.darkTheme(locale),
      home: homeWidget,
    );
  }
}
