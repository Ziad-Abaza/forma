import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../models/ai_config_model.dart';

class AIConfigRepository {
  final ApiClient apiClient;

  AIConfigRepository({required this.apiClient});

  Future<AIConfigModel> getAIConfig() async {
    final resp = await apiClient.get('/api/v1/ai/config');
    return AIConfigModel.fromJson(resp as Map<String, dynamic>);
  }

  Future<AICredentialModel> storeCredential({
    required String provider,
    required String apiKey,
  }) async {
    final resp = await apiClient.post('/api/v1/ai/credentials', body: {
      'provider': provider,
      'apiKey': apiKey,
    });
    final map = resp as Map<String, dynamic>;
    final credJson = (map['credential'] is Map) ? map['credential'] : map;
    return AICredentialModel.fromJson(credJson as Map<String, dynamic>);
  }

  Future<void> deleteCredential(String provider) async {
    await apiClient.delete('/api/v1/ai/credentials/$provider');
  }

  Future<bool> testConnection({required String provider, String? apiKey}) async {
    final body = <String, dynamic>{'provider': provider};
    if (apiKey != null && apiKey.isNotEmpty) {
      body['apiKey'] = apiKey;
    }
    final resp = await apiClient.post('/api/v1/ai/test-connection', body: body);
    return resp is Map && resp['status'] == 'success';
  }

  Future<void> updateActiveProvider(String provider) async {
    await apiClient.patch('/api/v1/ai/preferences', body: {
      'activeProvider': provider,
    });
  }
}

final aiConfigRepositoryProvider = Provider<AIConfigRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AIConfigRepository(apiClient: apiClient);
});

final aiConfigProvider = FutureProvider.autoDispose<AIConfigModel>((ref) async {
  final repo = ref.watch(aiConfigRepositoryProvider);
  return await repo.getAIConfig();
});
