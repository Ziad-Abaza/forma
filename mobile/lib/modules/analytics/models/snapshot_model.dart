class SnapshotModel {
  final double? latestWeightKg;
  final String? weightObservedAt;
  final double? trend7dKg;
  final double? weeklyRateKg;
  final double? bmi;
  final String? bmiCategory;

  // Goal
  final bool hasActiveGoal;
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
  final bool guardrailsTriggered;

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
    this.guardrailsTriggered = false,
    this.recentMeasurements = const [],
  });

  factory SnapshotModel.fromJson(Map<String, dynamic> json) {
    final sections = json['sections'] as Map<String, dynamic>? ?? json;

    final bodyStatus = sections['bodyStatus'] as Map<String, dynamic>? ?? {};
    final goal = sections['goal'] as Map<String, dynamic>? ?? {};
    final energy = sections['energy'] as Map<String, dynamic>? ?? {};
    final recentList = sections['recentMeasurements'] as List<dynamic>? ?? [];

    return SnapshotModel(
      latestWeightKg: (bodyStatus['latestWeightKg'] as num?)?.toDouble(),
      weightObservedAt: bodyStatus['observedAt'] as String?,
      trend7dKg: (bodyStatus['trend7dKg'] as num?)?.toDouble(),
      weeklyRateKg: (bodyStatus['weeklyRateKg'] as num?)?.toDouble(),
      bmi: (bodyStatus['bmi'] as num?)?.toDouble(),
      bmiCategory: bodyStatus['bmiCategory'] as String?,
      hasActiveGoal: goal['hasActiveGoal'] as bool? ?? false,
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
      guardrailsTriggered: energy['guardrailsTriggered'] as bool? ?? false,
      recentMeasurements: recentList
          .map((item) => SnapshotMeasurementItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SnapshotMeasurementItem {
  final String typeCode;
  final double canonicalValue;
  final String canonicalUnit;
  final String observedAt;
  final String epistemicClass;

  const SnapshotMeasurementItem({
    required this.typeCode,
    required this.canonicalValue,
    required this.canonicalUnit,
    required this.observedAt,
    required this.epistemicClass,
  });

  factory SnapshotMeasurementItem.fromJson(Map<String, dynamic> json) {
    return SnapshotMeasurementItem(
      typeCode: json['typeCode'] as String? ?? 'weight',
      canonicalValue: (json['canonicalValue'] as num?)?.toDouble() ?? 0.0,
      canonicalUnit: json['canonicalUnit'] as String? ?? 'kg',
      observedAt: json['observedAt'] as String? ?? '',
      epistemicClass: json['epistemicClass'] as String? ?? 'measured',
    );
  }
}
