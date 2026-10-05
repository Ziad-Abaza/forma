import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forma/core/config/env_config.dart';

void main() {
  group('EnvConfig Self-Contained Environment Tests', () {
    test('EnvConfig loads default values correctly', () {
      final config = EnvConfig.load();
      expect(config.environment, equals('development'));
      expect(config.isDevelopment, isTrue);
      expect(config.isProduction, isFalse);
      expect(config.apiTimeoutMs, equals(15000));
      expect(config.enableAnalyticsLogs, isFalse);
      expect(config.apiBaseUrl, isNotEmpty);
    });

    test('Riverpod envConfigProvider and apiBaseUrlProvider resolve', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final config = container.read(envConfigProvider);
      final baseUrl = container.read(apiBaseUrlProvider);

      expect(config.apiBaseUrl, equals(baseUrl));
    });
  });
}
