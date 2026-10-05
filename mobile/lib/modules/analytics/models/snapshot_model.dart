class SnapshotModel {
  final double? latestWeightKg;
  final String? weightObservedAt;
  final double? trend7dKg;
  final double? weeklyRateKg;
  final double? bmi;
  final String? bmiCategory;

  // Goal
  final bool hasActiveGoal;
  final String? goalId;
  final String? goalType;
  final double? targetValue;
  final double? startingValue;
  final double? currentValue;
  final double? progressPct;
  final bool isSafeRate;

  // Energy
  final double? bmr;
  final double? tdee;
  final double? maintenanceCalories;
  final double? targetCalories;
  final int? proteinGrams;
  final int? fatGrams;
  final int? carbsGrams;
  final bool guardrailsTriggered;
  final List<String> triggeredGuardrails;

  // Recent Measurements
  final List<SnapshotMeasurementItem> recentMeasurements;

  const SnapshotModel({
    this.latestWeightKg,
    this.weightObservedAt,
    this.trend7dKg,
    this.weeklyRateKg,
    this.bmi,
    this.bmiCategory,
    this.hasActiveGoal = false,
    this.goalId,
    this.goalType,
    this.targetValue,
    this.startingValue,
    this.currentValue,
    this.progressPct,
    this.isSafeRate = true,
    this.bmr,
    this.tdee,
    this.maintenanceCalories,
    this.targetCalories,
    this.proteinGrams,
    this.fatGrams,
    this.carbsGrams,
    this.guardrailsTriggered = false,
    this.triggeredGuardrails = const [],
    this.recentMeasurements = const [],
  });

  factory SnapshotModel.fromJson(Map<String, dynamic> json) {
    final sections = json['sections'] as Map<String, dynamic>? ?? json;

    final bodyStatus = sections['bodyStatus'] as Map<String, dynamic>? ?? {};
    final goal = sections['goal'] as Map<String, dynamic>? ?? {};
    final energy = sections['energy'] as Map<String, dynamic>? ?? {};
    final macros = energy['macros'] as Map<String, dynamic>? ?? {};
    final recentList = sections['recentMeasurements'] as List<dynamic>? ?? [];

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
      hasActiveGoal: goal['hasActiveGoal'] as bool? ?? false,
      goalId: goal['id'] as String?,
      goalType: goal['goalType'] as String?,
      targetValue: (goal['targetValue'] as num?)?.toDouble(),
      startingValue: (goal['startingValue'] as num?)?.toDouble(),
      currentValue: (goal['currentValue'] as num?)?.toDouble(),
      progressPct: (goal['progressPct'] as num?)?.toDouble(),
      isSafeRate: goal['isSafeRate'] as bool? ?? true,
      bmr: (energy['bmr'] as num?)?.toDouble(),
      tdee: (energy['tdee'] as num?)?.toDouble(),
      maintenanceCalories: (energy['maintenanceCalories'] as num?)?.toDouble(),
      targetCalories: (energy['targetCalories'] as num?)?.toDouble(),
      proteinGrams: (macros['proteinGrams'] as num?)?.toInt(),
      fatGrams: (macros['fatGrams'] as num?)?.toInt(),
      carbsGrams: (macros['carbsGrams'] as num?)?.toInt(),
      guardrailsTriggered: isGuardrailsTriggered,
      triggeredGuardrails: guardrailList,
      recentMeasurements: recentList
          .map((item) => SnapshotMeasurementItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SnapshotMeasurementItem {
  final String? id;
  final String typeCode;
  final double canonicalValue;
  final String canonicalUnit;
  final String observedAt;
  final String epistemicClass;

  const SnapshotMeasurementItem({
    this.id,
    required this.typeCode,
    required this.canonicalValue,
    required this.canonicalUnit,
    required this.observedAt,
    required this.epistemicClass,
  });

  factory SnapshotMeasurementItem.fromJson(Map<String, dynamic> json) {
    return SnapshotMeasurementItem(
      id: json['id'] as String?,
      typeCode: json['typeCode'] as String? ?? 'weight',
      canonicalValue: (json['canonicalValue'] as num?)?.toDouble() ?? 0.0,
      canonicalUnit: json['canonicalUnit'] as String? ?? 'kg',
      observedAt: json['observedAt'] as String? ?? '',
      epistemicClass: json['epistemicClass'] as String? ?? 'measured',
    );
  }
}
