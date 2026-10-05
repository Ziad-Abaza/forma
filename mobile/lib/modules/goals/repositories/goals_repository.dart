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
    final nowStr = DateTime.now().toIso8601String().substring(0, 10);
    final body = <String, dynamic>{
      'goalType': type,
      'type': type,
      'targetMetricTypeCode': 'weight',
      'targetValue': targetValue,
      'startingValue': baselineValue,
      'baselineValue': baselineValue,
      'ratePerWeek': ratePerWeek,
      'startDate': nowStr,
      'isPrimary': true,
    };
    if (targetDate != null) {
      body['targetDate'] = targetDate;
    }

    final resp = await apiClient.post('/api/v1/goals', body: body);
    return GoalModel.fromJson(resp as Map<String, dynamic>);
  }

  Future<GoalModel> addGoalVersion({
    required String goalId,
    required double targetValue,
    double? startingValue,
    double? weeklyRate,
    String? rationale,
    String? targetDate,
  }) async {
    final body = <String, dynamic>{
      'targetValue': targetValue,
      'startingValue': ?startingValue,
      'weeklyRate': ?weeklyRate,
      'rationale': ?rationale,
      'targetDate': ?targetDate,
    };
    final resp = await apiClient.post('/api/v1/goals/$goalId/versions', body: body);
    return GoalModel.fromJson(resp as Map<String, dynamic>);
  }

  Future<void> updateGoalStatus(String goalId, String status) async {
    await apiClient.patch('/api/v1/goals/$goalId/status', body: {'status': status});
  }
}

final goalsRepositoryProvider = Provider<GoalsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return GoalsRepository(apiClient: apiClient);
});
