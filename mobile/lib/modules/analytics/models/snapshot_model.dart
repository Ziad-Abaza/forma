/// Matches `HealthSnapshot` / `HealthSnapshotSections` in
/// backend/src/modules/analytics/contracts.ts (GET /api/v1/analytics/snapshot).
class SnapshotModel {
  final double? latestWeightKg;
  final String? weightObservedAt;
  final double? trend7dKg;
  final double? weeklyRateKg;
  final double? bmi;
  final String? bmiCategory;

  /// 'complete' | 'partial' | 'insufficient'
  final String? bodyStatusSufficiency;

  // Goal
  final bool hasActiveGoal;
  final String? goalId;
  final String? goalType;
  final String? targetMetricCode;
  final double? targetValue;
  final double? startingValue;
  final double? currentValue;
  final double? progressPct;

  /// Nullable on purpose: a missing value means "no active goal / not
  /// computed", NOT "safe". Callers must treat null as unknown.
  final bool? isSafeRate;

  final String? projectedTargetDate;

  // Energy
  final double? bmr;
  final double? tdee;
  final String? activityLevel;
  final double? maintenanceCalories;
  final double? targetCalories;
  final int? proteinGrams;
  final int? fatGrams;
  final int? carbsGrams;
  final double? proteinPct;
  final double? fatPct;
  final double? carbsPct;
  final bool guardrailsTriggered;
  final List<String> triggeredGuardrails;

  /// True when the calculation engine refused to emit calorie targets.
  final bool? isRefused;

  /// 'complete' | 'insufficient'
  final String? energySufficiency;

  // Recent Measurements
  final List<SnapshotMeasurementItem> recentMeasurements;

  // Additional sections (previously dropped silently)
  final List<SnapshotAnomaly> anomalies;
  final SnapshotDataQuality? dataQuality;
  final SnapshotIdentityLite? identityLite;

  const SnapshotModel({
    this.latestWeightKg,
    this.weightObservedAt,
    this.trend7dKg,
    this.weeklyRateKg,
    this.bmi,
    this.bmiCategory,
    this.bodyStatusSufficiency,
    this.hasActiveGoal = false,
    this.goalId,
    this.goalType,
    this.targetMetricCode,
    this.targetValue,
    this.startingValue,
    this.currentValue,
    this.progressPct,
    this.projectedTargetDate,
    this.isSafeRate,
    this.bmr,
    this.tdee,
    this.activityLevel,
    this.maintenanceCalories,
    this.targetCalories,
    this.proteinGrams,
    this.fatGrams,
    this.carbsGrams,
    this.proteinPct,
    this.fatPct,
    this.carbsPct,
    this.guardrailsTriggered = false,
    this.triggeredGuardrails = const [],
    this.isRefused,
    this.energySufficiency,
    this.recentMeasurements = const [],
    this.anomalies = const [],
    this.dataQuality,
    this.identityLite,
  });

  factory SnapshotModel.fromJson(Map<String, dynamic> json) {
    final sections = json['sections'] as Map<String, dynamic>? ?? json;

    final identity = sections['identityLite'] as Map<String, dynamic>?;
    final bodyStatus = sections['bodyStatus'] as Map<String, dynamic>? ?? {};
    final goal = sections['goal'] as Map<String, dynamic>? ?? {};
    final energy = sections['energy'] as Map<String, dynamic>? ?? {};
    final macros = energy['macros'] as Map<String, dynamic>? ?? {};
    final recentList = sections['recentMeasurements'] as List<dynamic>? ?? [];
    final anomaliesList = sections['anomalies'] as List<dynamic>? ?? [];
    final dataQuality = sections['dataQuality'] as Map<String, dynamic>?;

    // Contract: energy.guardrailsTriggered is a string[] of triggered
    // guardrail codes (always present on the backend).
    final rawGuardrails = energy['guardrailsTriggered'];
    bool isGuardrailsTriggered = false;
    List<String> guardrailList = [];
    if (rawGuardrails is bool) {
      isGuardrailsTriggered = rawGuardrails;
    } else if (rawGuardrails is List) {
      isGuardrailsTriggered = rawGuardrails.isNotEmpty;
      guardrailList = rawGuardrails.map((e) => e.toString()).toList();
    }

    return SnapshotModel(
      latestWeightKg: (bodyStatus['latestWeightKg'] as num?)?.toDouble(),
      weightObservedAt: bodyStatus['observedAt'] as String?,
      trend7dKg: (bodyStatus['trend7dKg'] as num?)?.toDouble(),
      weeklyRateKg: (bodyStatus['weeklyRateKg'] as num?)?.toDouble(),
      bmi: (bodyStatus['bmi'] as num?)?.toDouble(),
      bmiCategory: bodyStatus['bmiCategory'] as String?,
      bodyStatusSufficiency: bodyStatus['sufficiency'] as String?,
      hasActiveGoal: goal['hasActiveGoal'] as bool? ?? false,
      goalId: goal['id'] as String?,
      goalType: goal['goalType'] as String?,
      targetMetricCode: goal['targetMetricCode'] as String?,
      targetValue: (goal['targetValue'] as num?)?.toDouble(),
      startingValue: (goal['startingValue'] as num?)?.toDouble(),
      currentValue: (goal['currentValue'] as num?)?.toDouble(),
      progressPct: (goal['progressPct'] as num?)?.toDouble(),
      projectedTargetDate: goal['projectedTargetDate'] as String?,
      isSafeRate: goal['isSafeRate'] as bool?,
      bmr: (energy['bmr'] as num?)?.toDouble(),
      tdee: (energy['tdee'] as num?)?.toDouble(),
      activityLevel: energy['activityLevel'] as String?,
      maintenanceCalories: (energy['maintenanceCalories'] as num?)?.toDouble(),
      targetCalories: (energy['targetCalories'] as num?)?.toDouble(),
      proteinGrams: (macros['proteinGrams'] as num?)?.toInt(),
      fatGrams: (macros['fatGrams'] as num?)?.toInt(),
      carbsGrams: (macros['carbsGrams'] as num?)?.toInt(),
      proteinPct: (macros['proteinPct'] as num?)?.toDouble(),
      fatPct: (macros['fatPct'] as num?)?.toDouble(),
      carbsPct: (macros['carbsPct'] as num?)?.toDouble(),
      guardrailsTriggered: isGuardrailsTriggered,
      triggeredGuardrails: guardrailList,
      isRefused: energy['isRefused'] as bool?,
      energySufficiency: energy['sufficiency'] as String?,
      recentMeasurements: recentList
          .map((item) => SnapshotMeasurementItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      anomalies: anomaliesList
          .map((item) => SnapshotAnomaly.fromJson(item as Map<String, dynamic>))
          .toList(),
      dataQuality:
          dataQuality != null ? SnapshotDataQuality.fromJson(dataQuality) : null,
      identityLite:
          identity != null ? SnapshotIdentityLite.fromJson(identity) : null,
    );
  }
}

/// Matches `SnapshotRecentMeasurementItem` (backend always sends every field).
/// `epistemicClass` is nullable: a missing value must surface as unknown, not
/// silently become 'measured'.
class SnapshotMeasurementItem {
  final String? id;
  final String typeCode;
  final double canonicalValue;
  final String canonicalUnit;
  final String observedAt;
  final String? epistemicClass;

  const SnapshotMeasurementItem({
    this.id,
    required this.typeCode,
    required this.canonicalValue,
    required this.canonicalUnit,
    required this.observedAt,
    this.epistemicClass,
  });

  factory SnapshotMeasurementItem.fromJson(Map<String, dynamic> json) {
    return SnapshotMeasurementItem(
      id: json['id'] as String?,
      typeCode: json['typeCode'] as String,
      canonicalValue: (json['canonicalValue'] as num).toDouble(),
      canonicalUnit: json['canonicalUnit'] as String,
      observedAt: json['observedAt'] as String,
      epistemicClass: json['epistemicClass'] as String?,
    );
  }
}

/// Matches `AnomalyFlag` in backend/src/modules/analytics/contracts.ts.
class SnapshotAnomaly {
  final String? id;
  final String? observationId;

  /// 'implausible_jump' | 'unit_mismatch_suspect' | 'extreme_outlier'
  final String? flagType;

  /// 'info' | 'warning' | 'critical'
  final String? severity;
  final Map<String, dynamic> details;
  final String? createdAt;

  const SnapshotAnomaly({
    this.id,
    this.observationId,
    this.flagType,
    this.severity,
    this.details = const {},
    this.createdAt,
  });

  factory SnapshotAnomaly.fromJson(Map<String, dynamic> json) {
    return SnapshotAnomaly(
      id: json['id'] as String?,
      observationId: json['observationId'] as String?,
      flagType: json['flagType'] as String?,
      severity: json['severity'] as String?,
      details:
          json['details'] is Map<String, dynamic>
              ? json['details'] as Map<String, dynamic>
              : const {},
      createdAt: json['createdAt'] as String?,
    );
  }
}

/// Matches `SnapshotDataQualitySection`.
class SnapshotDataQuality {
  final int? totalActiveObservations;
  final double? measuredSharePct;
  final int? stalenessDays;
  final bool hasAnomalies;

  const SnapshotDataQuality({
    this.totalActiveObservations,
    this.measuredSharePct,
    this.stalenessDays,
    this.hasAnomalies = false,
  });

  factory SnapshotDataQuality.fromJson(Map<String, dynamic> json) {
    return SnapshotDataQuality(
      totalActiveObservations:
          (json['totalActiveObservations'] as num?)?.toInt(),
      measuredSharePct: (json['measuredSharePct'] as num?)?.toDouble(),
      stalenessDays: (json['stalenessDays'] as num?)?.toInt(),
      hasAnomalies: json['hasAnomalies'] as bool? ?? false,
    );
  }
}

/// Matches `SnapshotIdentityLiteSection`.
class SnapshotIdentityLite {
  final Map<String, String> units;
  final String? language;
  final int? ageYears;
  final String? sexForCalculation;
  final double? heightCm;

  const SnapshotIdentityLite({
    this.units = const {},
    this.language,
    this.ageYears,
    this.sexForCalculation,
    this.heightCm,
  });

  factory SnapshotIdentityLite.fromJson(Map<String, dynamic> json) {
    final rawUnits = json['units'];
    return SnapshotIdentityLite(
      units: rawUnits is Map
          ? rawUnits.map((k, v) => MapEntry(k.toString(), v.toString()))
          : const {},
      language: json['language'] as String?,
      ageYears: (json['ageYears'] as num?)?.toInt(),
      sexForCalculation: json['sexForCalculation'] as String?,
      heightCm: (json['heightCm'] as num?)?.toDouble(),
    );
  }
}
