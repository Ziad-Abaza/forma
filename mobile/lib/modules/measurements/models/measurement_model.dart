/// Matches `MeasurementTypeRecord` returned by GET /api/v1/measurements/types
/// (backend/src/modules/measurements/repository.ts). All fields are always
/// present on the backend; missing keys throw a parse error rather than
/// fabricating domain values.
class MeasurementTypeModel {
  final String code;
  final String category;
  final String dimension;
  final String canonicalUnit;
  final List<String> allowedUnits;
  final double minPlausible;
  final double maxPlausible;
  final String laterality;
  final bool isUserEnterable;
  final bool isDerived;

  const MeasurementTypeModel({
    required this.code,
    required this.category,
    required this.dimension,
    required this.canonicalUnit,
    required this.allowedUnits,
    required this.minPlausible,
    required this.maxPlausible,
    required this.laterality,
    required this.isUserEnterable,
    required this.isDerived,
  });

  factory MeasurementTypeModel.fromJson(Map<String, dynamic> json) {
    return MeasurementTypeModel(
      code: json['code'] as String,
      category: json['category'] as String,
      dimension: json['dimension'] as String,
      canonicalUnit: (json['canonicalUnit'] ?? json['canonical_unit']) as String,
      allowedUnits: ((json['allowedUnits'] ?? json['allowed_units']) as List<dynamic>)
          .map((e) => e.toString())
          .toList(),
      minPlausible: ((json['minPlausible'] ?? json['min_plausible']) as num).toDouble(),
      maxPlausible: ((json['maxPlausible'] ?? json['max_plausible']) as num).toDouble(),
      laterality: json['laterality'] as String,
      isUserEnterable: (json['isUserEnterable'] ?? json['is_user_enterable']) as bool,
      isDerived: (json['isDerived'] ?? json['is_derived']) as bool,
    );
  }
}

/// Matches `ObservationRecord` (snake_case JSON) returned by the measurements
/// endpoints. Fields that are always present are required — a missing key
/// throws a parse error instead of inventing a value.
///
/// Note: `epistemicClass` is NOT part of the observation row; it lives on the
/// linked provenance record (fetch via provenanceId). It stays nullable and is
/// only populated if a response happens to include it.
class ObservationModel {
  final String id;
  final String typeCode;
  final DateTime observedAt;
  final DateTime recordedAt;
  final String? timeZone;
  final double canonicalValue;
  final String canonicalUnit;
  final double originalValue;
  final String originalUnit;
  final String? epistemicClass;

  /// ID of the provenance record — pass THIS (not `id`) to
  /// `MeasurementsRepository.getProvenance`.
  final String? provenanceId;

  /// 'active' | 'superseded' | 'voided' — authoritative lifecycle state.
  final String status;
  final String? supersededBy;
  final String? supersedes;
  final List<String> qualityFlags;
  final String? voidReason;
  final DateTime? voidedAt;

  const ObservationModel({
    required this.id,
    required this.typeCode,
    required this.observedAt,
    required this.recordedAt,
    this.timeZone,
    required this.canonicalValue,
    required this.canonicalUnit,
    required this.originalValue,
    required this.originalUnit,
    this.epistemicClass,
    this.provenanceId,
    required this.status,
    this.supersededBy,
    this.supersedes,
    this.qualityFlags = const [],
    this.voidReason,
    this.voidedAt,
  });

  bool get isVoided => status == 'voided';
  bool get isSuperseded => status == 'superseded';
  bool get isActive => status == 'active';

  factory ObservationModel.fromJson(Map<String, dynamic> json) {
    final recordedRaw = json['recordedAt'] ?? json['recorded_at'];
    final observedRaw = json['observedAt'] ?? json['observed_at'];
    final voidedRaw = json['voidedAt'] ?? json['voided_at'];
    final flags = json['qualityFlags'] ?? json['quality_flags'];
    return ObservationModel(
      id: json['id'] as String,
      typeCode: (json['typeCode'] ?? json['type_code']) as String,
      observedAt: DateTime.parse(observedRaw as String),
      recordedAt: DateTime.parse(recordedRaw as String),
      timeZone: (json['timeZone'] ?? json['time_zone']) as String?,
      canonicalValue: ((json['canonicalValue'] ?? json['canonical_value']) as num).toDouble(),
      canonicalUnit: (json['canonicalUnit'] ?? json['canonical_unit']) as String,
      originalValue: ((json['originalValue'] ?? json['original_value']) as num).toDouble(),
      originalUnit: (json['originalUnit'] ?? json['original_unit']) as String,
      epistemicClass: (json['epistemicClass'] ?? json['epistemic_class']) as String?,
      provenanceId: (json['provenanceId'] ?? json['provenance_id']) as String?,
      status: json['status'] as String,
      supersededBy: (json['supersededBy'] ?? json['superseded_by']) as String?,
      supersedes: json['supersedes'] as String?,
      qualityFlags: flags is List ? flags.map((e) => e.toString()).toList() : const [],
      voidReason: (json['voidReason'] ?? json['void_reason']) as String?,
      voidedAt: voidedRaw is String ? DateTime.tryParse(voidedRaw) : null,
    );
  }
}
