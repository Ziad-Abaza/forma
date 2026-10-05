import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';

class PrivacyRepository {
  final ApiClient apiClient;

  PrivacyRepository({required this.apiClient});

  Future<Map<String, dynamic>> exportUserData() async {
    final resp = await apiClient.get('/api/v1/privacy/export');
    return resp as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> purgeAccount() async {
    final resp = await apiClient.delete('/api/v1/privacy/account');
    return resp as Map<String, dynamic>;
  }
}

final privacyRepositoryProvider = Provider<PrivacyRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PrivacyRepository(apiClient: apiClient);
});
