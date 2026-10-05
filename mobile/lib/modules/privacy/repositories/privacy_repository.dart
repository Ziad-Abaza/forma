import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../models/consent_model.dart';

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

  /// Lists the user's consent records including withdrawn state.
  Future<List<ConsentInfo>> listConsents() async {
    final resp = await apiClient.get('/api/v1/privacy/consents');
    if (resp is Map<String, dynamic>) {
      final raw = resp['consents'] as List<dynamic>? ?? const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(ConsentInfo.fromJson)
          .toList();
    }
    return const [];
  }

  /// Withdraws a consent. Only 'ai_third_party_processing' is withdrawable —
  /// the backend rejects terms/health-data withdrawal (400) since those
  /// require account deletion. Returns the raw response map.
  Future<Map<String, dynamic>> withdrawConsent(String policyType) async {
    final resp = await apiClient.post(
      '/api/v1/privacy/consents/$policyType/withdraw',
      body: const {},
    );
    return resp is Map<String, dynamic> ? resp : const {};
  }
}

final privacyRepositoryProvider = Provider<PrivacyRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PrivacyRepository(apiClient: apiClient);
});

/// Live list of the user's consent records for the settings UI.
final consentsProvider = FutureProvider.autoDispose<List<ConsentInfo>>((ref) async {
  final repo = ref.watch(privacyRepositoryProvider);
  return await repo.listConsents();
});
