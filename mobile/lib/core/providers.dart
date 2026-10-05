import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/env_config.dart';
import 'storage/token_storage.dart';
import 'storage/preferences_service.dart';
import 'network/api_client.dart';

export 'config/env_config.dart';
export 'storage/token_storage.dart';
export 'storage/preferences_service.dart';
export 'network/api_client.dart';

/// Provider for TokenStorage singleton
final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

/// Provider for centralized ApiClient
final apiClientProvider = Provider<ApiClient>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  return ApiClient(
    getBaseUrl: () => ref.watch(apiBaseUrlProvider),
    tokenStorage: tokenStorage,
    onSessionExpired: () {
      // Trigger logout if session expires and refresh fails
    },
  );
});

/// Riverpod StateProvider for Locale (survives app restarts via main override and updateAppLocale)
final localeProvider = StateProvider<Locale>((ref) {
  return const Locale('en');
});

/// Riverpod StateProvider for Numeral System (western vs eastern_arabic)
final numeralSystemProvider = StateProvider<String>((ref) {
  return 'western';
});

/// Sets active locale, persists to SharedPreferences, and syncs to backend if authenticated
Future<void> updateAppLocale(WidgetRef ref, Locale newLocale) async {
  ref.read(localeProvider.notifier).state = newLocale;
  await PreferencesService.saveLocale(newLocale);

  try {
    final token = await ref.read(tokenStorageProvider).getAccessToken();
    if (token != null && token.isNotEmpty) {
      final client = ref.read(apiClientProvider);
      await client.patch('/api/v1/auth/preferences', body: {
        'locale': newLocale.languageCode,
      });
    }
  } catch (_) {}
}

/// Sets numeral system, persists to SharedPreferences, and syncs to backend if authenticated
Future<void> updateAppNumeralSystem(WidgetRef ref, String newSystem) async {
  ref.read(numeralSystemProvider.notifier).state = newSystem;
  await PreferencesService.saveNumeralSystem(newSystem);

  try {
    final token = await ref.read(tokenStorageProvider).getAccessToken();
    if (token != null && token.isNotEmpty) {
      final client = ref.read(apiClientProvider);
      await client.patch('/api/v1/auth/preferences', body: {
        'numeralSystem': newSystem,
      });
    }
  } catch (_) {}
}

String formatNumeralString(String input, String numeralSystem) {
  if (numeralSystem == 'western') return input;

  const arabicIndicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return input.replaceAllMapped(RegExp(r'\d'), (match) {
    final digit = int.parse(match.group(0)!);
    return arabicIndicDigits[digit];
  });
}
