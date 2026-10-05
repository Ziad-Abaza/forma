import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Self-contained environment configuration for Forma Mobile.
///
/// Values can be populated via:
/// `flutter run --dart-define-from-file=.env`
/// or individual `--dart-define=KEY=VALUE` flags.
/// Sensible development defaults are provided automatically.
@immutable
class EnvConfig {
  final String apiBaseUrl;
  final String environment;
  final int apiTimeoutMs;
  final bool enableAnalyticsLogs;

  const EnvConfig({
    required this.apiBaseUrl,
    required this.environment,
    required this.apiTimeoutMs,
    required this.enableAnalyticsLogs,
  });

  static EnvConfig load() {
    const rawUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    const environment = String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');
    const timeout = int.fromEnvironment('API_TIMEOUT_MS', defaultValue: 15000);
    const analyticsLogs = bool.fromEnvironment('ENABLE_ANALYTICS_LOGS', defaultValue: false);

    // Provide sensible default when not specified
    String effectiveBaseUrl = rawUrl;
    if (effectiveBaseUrl.isEmpty) {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        effectiveBaseUrl = 'http://10.0.2.2:3000';
      } else {
        effectiveBaseUrl = 'http://localhost:3000';
      }
    }

    return EnvConfig(
      apiBaseUrl: effectiveBaseUrl,
      environment: environment,
      apiTimeoutMs: timeout,
      enableAnalyticsLogs: analyticsLogs,
    );
  }

  bool get isDevelopment => environment == 'development';
  bool get isProduction => environment == 'production';
}

/// Riverpod provider for active environment configuration
final envConfigProvider = Provider<EnvConfig>((ref) {
  return EnvConfig.load();
});

/// Riverpod provider for convenient access to backend API Base URL
final apiBaseUrlProvider = Provider<String>((ref) {
  return ref.watch(envConfigProvider).apiBaseUrl;
});
