import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';

class IntegrationConnectionModel {
  final String id;
  final String provider;
  final String status;
  final List<String> scopes;
  final String? lastSyncedAt;

  const IntegrationConnectionModel({
    required this.id,
    required this.provider,
    required this.status,
    this.scopes = const [],
    this.lastSyncedAt,
  });

  bool get isConnected => status == 'connected';

  factory IntegrationConnectionModel.fromJson(Map<String, dynamic> json) {
    return IntegrationConnectionModel(
      id: json['id'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      status: json['status'] as String? ?? 'revoked',
      scopes: (json['scopes'] as List?)?.map((e) => e.toString()).toList() ?? [],
      lastSyncedAt: json['lastSyncedAt'] as String?,
    );
  }
}

class IntegrationsRepository {
  final ApiClient apiClient;

  IntegrationsRepository({required this.apiClient});

  Future<List<IntegrationConnectionModel>> getConnections() async {
    final resp = await apiClient.get('/api/v1/integrations/connections');
    if (resp is Map && resp['connections'] is List) {
      return (resp['connections'] as List)
          .map((item) => IntegrationConnectionModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<IntegrationConnectionModel> connectProvider(String provider, {List<String>? scopes}) async {
    final resp = await apiClient.post('/api/v1/integrations/connect', body: {
      'provider': provider,
      'scopes': scopes ?? ['read:measurements', 'read:activity'],
    });
    final map = resp as Map<String, dynamic>;
    final connMap = (map['connection'] is Map) ? map['connection'] as Map<String, dynamic> : map;
    return IntegrationConnectionModel.fromJson(connMap);
  }

  Future<void> disconnectProvider(String provider) async {
    await apiClient.post('/api/v1/integrations/disconnect', body: {
      'provider': provider,
    });
  }

  /// Provider catalog is server-issued (IntegrationProviderSchema) — the client
  /// must never fabricate or hardcode the list.
  Future<List<String>> getProviders() async {
    final resp = await apiClient.get('/api/v1/integrations/providers');
    if (resp is Map && resp['providers'] is List) {
      return (resp['providers'] as List).map((e) => e.toString()).toList();
    }
    throw ApiException(
      statusCode: 0,
      message: 'Malformed response from /api/v1/integrations/providers',
    );
  }

  /// Syncs device-sourced records for [provider]. [records] is required and may
  /// be empty — the client never fabricates health observations.
  Future<Map<String, dynamic>> syncProvider(String provider, {required List<Map<String, dynamic>> records}) async {
    final resp = await apiClient.post('/api/v1/integrations/sync', body: {
      'provider': provider,
      'records': records,
    });
    return resp as Map<String, dynamic>;
  }
}

final integrationsRepositoryProvider = Provider<IntegrationsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return IntegrationsRepository(apiClient: apiClient);
});
