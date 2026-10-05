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
  final bool isLocalServer;
  final String? localIp;

  const EnvConfig({
    required this.apiBaseUrl,
    required this.environment,
    required this.apiTimeoutMs,
    required this.enableAnalyticsLogs,
    this.isLocalServer = false,
    this.localIp,
  });

  /// Loads configuration from compile-time environment flags and defaults.
  static EnvConfig load({
    String? apiBaseUrl,
    String? environment,
    int? apiTimeoutMs,
    bool? enableAnalyticsLogs,
    bool? isLocalServer,
    String? localIp,
  }) {
    const rawUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    const rawEnv = String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');
    const rawTimeout = int.fromEnvironment('API_TIMEOUT_MS', defaultValue: 15000);
    const rawAnalyticsLogs = bool.fromEnvironment('ENABLE_ANALYTICS_LOGS', defaultValue: false);
    const rawLocalServer = String.fromEnvironment('LOCAL_SERVER', defaultValue: '');
    const boolLocalServer = bool.fromEnvironment('LOCAL_SERVER', defaultValue: false);
    const rawLocalIp = String.fromEnvironment('LOCAL_IP', defaultValue: '');

    final effectiveLocalServer = isLocalServer ?? (boolLocalServer || rawLocalServer.toLowerCase() == 'true');
    final effectiveLocalIp = localIp ?? (rawLocalIp.isNotEmpty ? rawLocalIp : null);

    String effectiveBaseUrl = apiBaseUrl ?? rawUrl;

    if (effectiveLocalServer) {
      if (effectiveLocalIp != null && effectiveLocalIp.isNotEmpty) {
        if (effectiveBaseUrl.isEmpty) {
          effectiveBaseUrl = 'http://$effectiveLocalIp:3000';
        } else {
          effectiveBaseUrl = replaceHostWithLocalIp(effectiveBaseUrl, effectiveLocalIp);
        }
      } else {
        if (effectiveBaseUrl.isEmpty) {
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
            effectiveBaseUrl = 'http://10.0.2.2:3000';
          } else {
            effectiveBaseUrl = 'http://localhost:3000';
          }
        }
      }
    } else {
      if (effectiveBaseUrl.isEmpty) {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          effectiveBaseUrl = 'http://10.0.2.2:3000';
        } else {
          effectiveBaseUrl = 'http://localhost:3000';
        }
      }
    }

    return EnvConfig(
      apiBaseUrl: effectiveBaseUrl,
      environment: environment ?? rawEnv,
      apiTimeoutMs: apiTimeoutMs ?? rawTimeout,
      enableAnalyticsLogs: enableAnalyticsLogs ?? rawAnalyticsLogs,
      isLocalServer: effectiveLocalServer,
      localIp: effectiveLocalIp,
    );
  }

  /// Replaces loopback host names (localhost, 127.0.0.1, 10.0.2.2) with the computer's local network IP.
  static String replaceHostWithLocalIp(String url, String localIp) {
    try {
      final uri = Uri.parse(url);
      if (uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '10.0.2.2' || uri.host.isEmpty) {
        return uri.replace(host: localIp).toString();
      }
      return url;
    } catch (_) {
      return url
          .replaceAll('localhost', localIp)
          .replaceAll('127.0.0.1', localIp)
          .replaceAll('10.0.2.2', localIp);
    }
  }

  EnvConfig copyWith({
    String? apiBaseUrl,
    String? environment,
    int? apiTimeoutMs,
    bool? enableAnalyticsLogs,
    bool? isLocalServer,
    String? localIp,
  }) {
    return EnvConfig(
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      environment: environment ?? this.environment,
      apiTimeoutMs: apiTimeoutMs ?? this.apiTimeoutMs,
      enableAnalyticsLogs: enableAnalyticsLogs ?? this.enableAnalyticsLogs,
      isLocalServer: isLocalServer ?? this.isLocalServer,
      localIp: localIp ?? this.localIp,
    );
  }

  bool get isDevelopment => environment == 'development';
  bool get isProduction => environment == 'production';
}

/// State notifier for dynamic environment configuration updates (e.g. dynamic local IP discovery).
class EnvConfigNotifier extends Notifier<EnvConfig> {
  @override
  EnvConfig build() {
    return EnvConfig.load();
  }

  void updateBaseUrl(String newUrl) {
    state = state.copyWith(apiBaseUrl: newUrl);
  }

  void updateLocalIp(String localIp) {
    final updated = EnvConfig.replaceHostWithLocalIp(state.apiBaseUrl, localIp);
    state = state.copyWith(localIp: localIp, apiBaseUrl: updated);
  }

  void setConfig(EnvConfig config) {
    state = config;
  }
}

/// Riverpod provider for active environment configuration
final envConfigProvider = NotifierProvider<EnvConfigNotifier, EnvConfig>(() {
  return EnvConfigNotifier();
});

/// Riverpod provider for convenient access to backend API Base URL
final apiBaseUrlProvider = Provider<String>((ref) {
  return ref.watch(envConfigProvider).apiBaseUrl;
});
