import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../models/goal_model.dart';

class GoalsRepository {
  final ApiClient apiClient;

  GoalsRepository({required this.apiClient});

  /// Backend GoalType enum (contracts.ts):
  /// 'weight_loss' | 'muscle_gain' | 'maintenance' | 'general_fitness'.
  /// Older UI code emits 'weight_gain' for the muscle-gain option — normalize
  /// it to the contract enum so zod validation does not reject the request.
  static const Map<String, String> _goalTypeAliases = {
    'weight_gain': 'muscle_gain',
  };

  static String _normalizeGoalType(String type) => _goalTypeAliases[type] ?? type;

  Future<GoalModel?> getPrimaryGoal() async {
    final resp = await apiClient.get('/api/v1/goals/primary');
    if (resp is Map && resp['goal'] != null) {
      return GoalModel.fromJson(resp['goal'] as Map<String, dynamic>);
    }
    return null;
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

  /// POST /api/v1/goals — body must satisfy CreateGoalRequestSchema.
  /// Returns the created [GoalModel] (backend responds 201 with the Goal).
  Future<GoalModel> createGoal({
    required String type,
    required double targetValue,
    required double baselineValue,
    double? ratePerWeek,
    String? targetDate,
    String? targetMetricTypeCode,
    String? rationale,
  }) async {
    final nowStr = DateTime.now().toIso8601String().substring(0, 10);
    final body = <String, dynamic>{
      'goalType': _normalizeGoalType(type),
      'targetMetricTypeCode': ?targetMetricTypeCode,
      'targetValue': targetValue,
      'startingValue': baselineValue,
      'weeklyRate': ?ratePerWeek,
      'startDate': nowStr,
      'isPrimary': true,
      'targetDate': ?targetDate,
      'rationale': ?rationale,
    };

    final resp = await apiClient.post('/api/v1/goals', body: body);
    return GoalModel.fromJson(resp as Map<String, dynamic>);
  }

  /// POST /api/v1/goals/:id/versions — body satisfies
  /// UpdateGoalVersionRequestSchema. Returns the updated [GoalModel].
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

  /// GET /api/v1/goals/:id/versions — immutable version history.
  Future<List<GoalVersionModel>> listGoalVersions(String goalId) async {
    final resp = await apiClient.get('/api/v1/goals/$goalId/versions');
    if (resp is Map && resp['versions'] is List) {
      return (resp['versions'] as List)
          .map((item) => GoalVersionModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Backend accepts only 'active' | 'achieved' | 'abandoned' | 'superseded'.
  Future<void> updateGoalStatus(String goalId, String status) async {
    await apiClient.patch('/api/v1/goals/$goalId/status', body: {'status': status});
  }
}

final goalsRepositoryProvider = Provider<GoalsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return GoalsRepository(apiClient: apiClient);
});
