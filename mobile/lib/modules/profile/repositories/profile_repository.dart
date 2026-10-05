import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../models/profile_model.dart';

class ProfileRepository {
  final ApiClient apiClient;

  ProfileRepository({required this.apiClient});

  Future<ProfileModel?> getProfile() async {
    final resp = await apiClient.get('/api/v1/profile');
    if (resp is Map<String, dynamic>) {
      return ProfileModel.fromJson(resp);
    }
    return null;
  }

  Future<ProfileModel> updateProfile({
    String? dateOfBirth,
    double? heightCm,
    String? sexForCalculation,
    String? activityLevel,
    String? experienceLevel,
    List<String>? constraints,
  }) async {
    final body = <String, dynamic>{};
    if (dateOfBirth != null) body['dateOfBirth'] = dateOfBirth;
    if (heightCm != null) body['heightCm'] = heightCm;
    if (sexForCalculation != null) body['sexForCalculation'] = sexForCalculation;
    if (activityLevel != null) body['activityLevel'] = activityLevel;
    if (experienceLevel != null) body['experienceLevel'] = experienceLevel;
    if (constraints != null) body['constraints'] = constraints;

    final resp = await apiClient.put('/api/v1/profile', body: body);
    return ProfileModel.fromJson(resp as Map<String, dynamic>);
  }

  Future<List<ProfileHistoryItem>> getHistory({String? attribute}) async {
    final query = attribute != null ? {'attribute': attribute} : null;
    final resp = await apiClient.get('/api/v1/profile/history', queryParameters: query);
    if (resp is Map && resp['history'] is List) {
      return (resp['history'] as List)
          .map((item) => ProfileHistoryItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ProfileRepository(apiClient: apiClient);
});

final userProfileProvider = FutureProvider.autoDispose<ProfileModel?>((ref) async {
  final repo = ref.watch(profileRepositoryProvider);
  return await repo.getProfile();
});
