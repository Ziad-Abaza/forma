import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../models/measurement_model.dart';

class MeasurementsRepository {
  final ApiClient apiClient;

  MeasurementsRepository({required this.apiClient});

  Future<List<MeasurementTypeModel>> listTypes() async {
    final resp = await apiClient.get('/api/v1/measurements/types', requireAuth: false);
    if (resp is Map && resp['types'] is List) {
      return (resp['types'] as List)
          .map((item) => MeasurementTypeModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<ObservationModel>> getObservations({String? typeCode, int limit = 50}) async {
    final query = <String, dynamic>{'limit': limit};
    if (typeCode != null) query['typeCode'] = typeCode;

    final resp = await apiClient.get('/api/v1/measurements/observations', queryParameters: query);
    if (resp is Map && resp['observations'] is List) {
      return (resp['observations'] as List)
          .map((item) => ObservationModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<ObservationModel> recordObservation({
    required String typeCode,
    required double value,
    required String unit,
    DateTime? observedAt,
    String originType = 'manual_entry',
  }) async {
    final body = {
      'typeCode': typeCode,
      'value': value,
      'unit': unit,
      'observedAt': (observedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'originType': originType,
    };

    final resp = await apiClient.post('/api/v1/measurements/observations', body: body);
    final obsJson = (resp is Map && resp['observation'] != null) ? resp['observation'] : resp;
    return ObservationModel.fromJson(obsJson as Map<String, dynamic>);
  }

  Future<void> voidObservation(String observationId, String reason) async {
    await apiClient.post(
      '/api/v1/measurements/observations/$observationId/void',
      body: {'reason': reason},
    );
  }

  Future<ObservationModel> supersedeObservation({
    required String observationId,
    required double newValue,
    required String newUnit,
    required String correctionReason,
    DateTime? observedAt,
  }) async {
    final body = {
      'newValue': newValue,
      'newUnit': newUnit,
      'correctionReason': correctionReason,
      if (observedAt != null) 'observedAt': observedAt.toUtc().toIso8601String(),
    };
    final resp = await apiClient.post(
      '/api/v1/measurements/observations/$observationId/supersede',
      body: body,
    );
    final obsJson = (resp is Map && resp['observation'] != null) ? resp['observation'] : resp;
    return ObservationModel.fromJson(obsJson as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>?> getProvenance(String observationId) async {
    try {
      final resp = await apiClient.get('/api/v1/measurements/provenance/$observationId');
      return resp is Map<String, dynamic> ? resp : null;
    } catch (_) {
      return null;
    }
  }
}

final measurementsRepositoryProvider = Provider<MeasurementsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return MeasurementsRepository(apiClient: apiClient);
});
