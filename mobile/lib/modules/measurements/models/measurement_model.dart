class MeasurementTypeModel {
  final String code;
  final String category;
  final String dimension;
  final String canonicalUnit;
  final List<String> allowedUnits;
  final double minPlausible;
  final double maxPlausible;

  const MeasurementTypeModel({
    required this.code,
    required this.category,
    required this.dimension,
    required this.canonicalUnit,
    required this.allowedUnits,
    required this.minPlausible,
    required this.maxPlausible,
  });

  factory MeasurementTypeModel.fromJson(Map<String, dynamic> json) {
    return MeasurementTypeModel(
      code: json['code'] as String,
      category: json['category'] as String,
      dimension: json['dimension'] as String,
      canonicalUnit: json['canonicalUnit'] ?? json['canonical_unit'] ?? 'kg',
      allowedUnits: (json['allowedUnits'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          (json['allowed_units'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          ['kg'],
      minPlausible: (json['minPlausible'] ?? json['min_plausible'] as num?)?.toDouble() ?? 0.0,
      maxPlausible: (json['maxPlausible'] ?? json['max_plausible'] as num?)?.toDouble() ?? 1000.0,
    );
  }
}

class ObservationModel {
  final String id;
  final String typeCode;
  final DateTime recordedAt;
  final double canonicalValue;
  final String canonicalUnit;
  final double originalValue;
  final String originalUnit;
  final String epistemicClass;
  final bool isVoided;
  final String? supersededBy;

  const ObservationModel({
    required this.id,
    required this.typeCode,
    required this.recordedAt,
    required this.canonicalValue,
    required this.canonicalUnit,
    required this.originalValue,
    required this.originalUnit,
    required this.epistemicClass,
    this.isVoided = false,
    this.supersededBy,
  });

  factory ObservationModel.fromJson(Map<String, dynamic> json) {
    final recordedRaw = json['recordedAt'] ?? json['recorded_at'];
    return ObservationModel(
      id: json['id'] as String,
      typeCode: json['typeCode'] ?? json['type_code'] ?? 'weight_body',
      recordedAt: recordedRaw is String ? DateTime.parse(recordedRaw) : DateTime.now(),
      canonicalValue: (json['canonicalValue'] ?? json['canonical_value'] as num).toDouble(),
      canonicalUnit: json['canonicalUnit'] ?? json['canonical_unit'] ?? 'kg',
      originalValue: (json['originalValue'] ?? json['original_value'] as num).toDouble(),
      originalUnit: json['originalUnit'] ?? json['original_unit'] ?? 'kg',
      epistemicClass: json['epistemicClass'] ?? json['epistemic_class'] ?? 'measured',
      isVoided: (json['isVoided'] ?? json['is_voided'] as bool?) ?? false,
      supersededBy: json['supersededBy'] ?? json['superseded_by'],
    );
  }
}
