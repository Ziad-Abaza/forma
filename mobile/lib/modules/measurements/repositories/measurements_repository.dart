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

  /// [status] passes through to QueryObservationsFilterSchema — allowed
  /// values: 'active' (backend default), 'superseded', 'voided', 'all'.
  Future<List<ObservationModel>> getObservations({
    String? typeCode,
    String? status,
    int limit = 50,
  }) async {
    final query = <String, dynamic>{'limit': limit};
    if (typeCode != null) query['typeCode'] = typeCode;
    if (status != null) query['status'] = status;

    final resp = await apiClient.get('/api/v1/measurements/observations', queryParameters: query);
    if (resp is Map && resp['observations'] is List) {
      return (resp['observations'] as List)
          .map((item) => ObservationModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Device-local timezone as 'UTC±HH:MM' — the only truthful timezone
  /// Dart can provide without an IANA lookup package.
  static String _deviceTimeZone() {
    final off = DateTime.now().timeZoneOffset;
    final sign = off.isNegative ? '-' : '+';
    final hh = off.inHours.abs().toString().padLeft(2, '0');
    final mm = (off.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return 'UTC$sign$hh:$mm';
  }

  Future<ObservationModel> recordObservation({
    required String typeCode,
    required double value,
    required String unit,
    DateTime? observedAt,
    String originType = 'manual_entry',
  }) async {
    // Note: provenance fields are stamped by the server; `originType` is no
    // longer sent — the public route cannot be used to claim provenance.
    final body = {
      'typeCode': typeCode,
      'value': value,
      'unit': unit,
      'observedAt': (observedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'timeZone': _deviceTimeZone(),
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
    // Backend returns { newObservation, previousObservation } — the caller
    // wants the newly written correction record.
    final obsJson = (resp is Map && resp['newObservation'] is Map)
        ? resp['newObservation']
        : resp;
    return ObservationModel.fromJson(obsJson as Map<String, dynamic>);
  }

  /// Fetches a provenance record.
  ///
  /// IMPORTANT: [provenanceId] must be the observation's provenance id
  /// (`ObservationModel.provenanceId`), NOT the observation id —
  /// `GET /api/v1/measurements/provenance/:id` looks up `provenance_records`
  /// by their own primary key. Errors (including 404s) propagate to the
  /// caller.
  Future<Map<String, dynamic>?> getProvenance(String provenanceId) async {
    final resp = await apiClient.get('/api/v1/measurements/provenance/$provenanceId');
    return resp is Map<String, dynamic> ? resp : null;
  }
}

final measurementsRepositoryProvider = Provider<MeasurementsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return MeasurementsRepository(apiClient: apiClient);
});

/// Server-issued measurement type catalog (`GET /api/v1/measurements/types`).
/// The single source of truth for pickers — never hardcode type lists.
final measurementTypesProvider = FutureProvider<List<MeasurementTypeModel>>((ref) {
  return ref.watch(measurementsRepositoryProvider).listTypes();
});
