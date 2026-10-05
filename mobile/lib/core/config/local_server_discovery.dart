import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'env_config.dart';

/// Dynamic local server discovery service for physical devices on a Wi-Fi network.
///
/// When running with `LOCAL_SERVER=true` on a physical device, this service can
/// probe candidate local network IPv4 addresses to dynamically find and bind
/// to the Forma backend running on the developer's computer.
class LocalServerDiscovery {
  /// Probes an endpoint to verify whether it is an active Forma backend instance.
  static Future<bool> isFormaBackendHealthy(
    String baseUrl, {
    Duration timeout = const Duration(milliseconds: 800),
  }) async {
    if (kIsWeb) return false;
    HttpClient? client;
    try {
      final uri = Uri.parse('$baseUrl/health');
      client = HttpClient()..connectionTimeout = timeout;
      final request = await client.getUrl(uri).timeout(timeout);
      final response = await request.close().timeout(timeout);

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        return body.contains('healthy') || body.contains('version');
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  /// Discovers the backend IPv4 address on the current local Wi-Fi subnet.
  static Future<String?> discoverBackendIp({
    int port = 3000,
    Duration probeTimeout = const Duration(milliseconds: 600),
    int maxSubnetScan = 50,
  }) async {
    if (kIsWeb) return null;

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      final candidateSubnets = <String>{};
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && !addr.isLinkLocal) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              candidateSubnets.add('${parts[0]}.${parts[1]}.${parts[2]}');
            }
          }
        }
      }

      for (final subnet in candidateSubnets) {
        // Prioritize common host addresses (.1 gateway, .2-.30 common DHCP assignments)
        final priorityHosts = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 50, 100];
        for (final host in priorityHosts) {
          final candidateIp = '$subnet.$host';
          final isHealthy = await isFormaBackendHealthy('http://$candidateIp:$port', timeout: probeTimeout);
          if (isHealthy) {
            return candidateIp;
          }
        }
      }
    } catch (e) {
      debugPrint('[LocalServerDiscovery] Discovery error: $e');
    }

    return null;
  }

  /// Automatically discovers and applies the local server IP if in LOCAL_SERVER mode and current URL fails.
  static Future<void> autoDiscoverAndApply(ProviderContainer container) async {
    final config = container.read(envConfigProvider);
    if (!config.isLocalServer) return;

    final isCurrentlyHealthy = await isFormaBackendHealthy(config.apiBaseUrl);
    if (isCurrentlyHealthy) return;

    debugPrint('[LocalServerDiscovery] Current backend URL (${config.apiBaseUrl}) not reachable. Probing local network...');
    final discoveredIp = await discoverBackendIp();
    if (discoveredIp != null) {
      debugPrint('[LocalServerDiscovery] Found local Forma backend at: $discoveredIp');
      container.read(envConfigProvider.notifier).updateLocalIp(discoveredIp);
    }
  }
}
