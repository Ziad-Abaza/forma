import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../models/snapshot_model.dart';

class AnalyticsRepository {
  final ApiClient apiClient;

  AnalyticsRepository({required this.apiClient});

  Future<SnapshotModel> getSnapshot() async {
    final resp = await apiClient.get('/api/v1/analytics/snapshot');
    return SnapshotModel.fromJson(resp as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getTrend(String typeCode, int windowDays) async {
    final resp = await apiClient.get(
      '/api/v1/analytics/trends/$typeCode',
      queryParameters: {'windowDays': windowDays},
    );
    return resp as Map<String, dynamic>;
  }
}

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AnalyticsRepository(apiClient: apiClient);
});

final dashboardSnapshotProvider = FutureProvider.autoDispose<SnapshotModel>((ref) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  return await repo.getSnapshot();
});

final trendAnalysisProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, (String, int)>((ref, params) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  return await repo.getTrend(params.$1, params.$2);
});
