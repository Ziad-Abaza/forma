import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../models/goal_model.dart';

class GoalsRepository {
  final ApiClient apiClient;

  GoalsRepository({required this.apiClient});

  Future<GoalModel?> getPrimaryGoal() async {
    try {
      final resp = await apiClient.get('/api/v1/goals/primary');
      if (resp is Map && resp['goal'] != null) {
        return GoalModel.fromJson(resp['goal'] as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<GoalModel>> listGoals() async {
    final resp = await apiClient.get('/api/v1/goals');
    if (resp is Map && resp['goals'] is List) {
      return (resp['goals'] as List)
          .map((item) => GoalModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<GoalModel> createGoal({
    required String type,
    required double targetValue,
    required double baselineValue,
    double ratePerWeek = 0.5,
    String? targetDate,
  }) async {
    final body = <String, dynamic>{
      'type': type,
      'targetValue': targetValue,
      'baselineValue': baselineValue,
      'ratePerWeek': ratePerWeek,
    };
    if (targetDate != null) {
      body['targetDate'] = targetDate;
    }

    final resp = await apiClient.post('/api/v1/goals', body: body);
    return GoalModel.fromJson(resp as Map<String, dynamic>);
  }
}

final goalsRepositoryProvider = Provider<GoalsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return GoalsRepository(apiClient: apiClient);
});
