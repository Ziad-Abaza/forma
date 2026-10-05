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
      expect(config.apiTimeoutMs, equals(30000));
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

    test('replaceHostWithLocalIp replaces localhost, 127.0.0.1, 10.0.2.2, and existing IPv4 with local IPv4', () {
      expect(
        EnvConfig.replaceHostWithLocalIp('http://localhost:3000', '192.168.1.50'),
        equals('http://192.168.1.50:3000'),
      );
      expect(
        EnvConfig.replaceHostWithLocalIp('http://127.0.0.1:3000', '192.168.1.50'),
        equals('http://192.168.1.50:3000'),
      );
      expect(
        EnvConfig.replaceHostWithLocalIp('http://10.0.2.2:3000', '192.168.1.50'),
        equals('http://192.168.1.50:3000'),
      );
      expect(
        EnvConfig.replaceHostWithLocalIp('http://192.168.100.99:3000', '192.168.100.5'),
        equals('http://192.168.100.5:3000'),
      );
      expect(
        EnvConfig.replaceHostWithLocalIp('http://localhost:8080/api/v1', '192.168.100.5'),
        equals('http://192.168.100.5:8080/api/v1'),
      );
    });

    test('EnvConfig.load dynamically switches API Base URL when isLocalServer=true and localIp is set', () {
      final config = EnvConfig.load(
        isLocalServer: true,
        localIp: '192.168.100.5',
        apiBaseUrl: 'http://localhost:3000',
      );

      expect(config.isLocalServer, isTrue);
      expect(config.localIp, equals('192.168.100.5'));
      expect(config.apiBaseUrl, equals('http://192.168.100.5:3000'));
    });

    test('EnvConfigNotifier dynamically updates baseUrl and notifies listeners', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(envConfigProvider.notifier);
      notifier.updateLocalIp('192.168.100.42');

      final updatedConfig = container.read(envConfigProvider);
      final updatedBaseUrl = container.read(apiBaseUrlProvider);

      expect(updatedConfig.localIp, equals('192.168.100.42'));
      expect(updatedBaseUrl, contains('192.168.100.42'));
      expect(updatedConfig.apiBaseUrl, equals(updatedBaseUrl));
    });
  });
}
