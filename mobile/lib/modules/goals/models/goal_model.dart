class GoalModel {
  final String id;
  final String type;
  final double targetValue;
  final String? targetDate;
  final String status;
  final double baselineValue;
  final double ratePerWeek;
  final int version;

  const GoalModel({
    required this.id,
    required this.type,
    required this.targetValue,
    this.targetDate,
    required this.status,
    required this.baselineValue,
    required this.ratePerWeek,
    this.version = 1,
  });

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    final v = json['currentVersion'] as Map<String, dynamic>? ?? {};
    return GoalModel(
      id: json['id'] as String,
      type: json['type'] as String,
      targetValue: (json['targetValue'] ?? json['target_value'] as num).toDouble(),
      targetDate: json['targetDate'] ?? json['target_date'] as String?,
      status: (json['status'] as String?) ?? 'active',
      baselineValue: (v['baselineValue'] ?? v['baseline_value'] ?? json['baselineValue'] ?? json['baseline_value'] as num?)?.toDouble() ?? 0.0,
      ratePerWeek: (v['ratePerWeek'] ?? v['rate_per_week'] ?? json['ratePerWeek'] ?? json['rate_per_week'] as num?)?.toDouble() ?? 0.0,
      version: (v['version'] ?? json['version'] as num?)?.toInt() ?? 1,
    );
  }
}
