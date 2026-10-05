/// Matches `GoalVersion` in backend/src/modules/goals/contracts.ts.
class GoalVersionModel {
  final String id;
  final String goalId;
  final String userId;
  final int version;
  final double targetValue;
  final double startingValue;
  final double? weeklyRate;
  final String startDate; // YYYY-MM-DD
  final String? targetDate; // YYYY-MM-DD
  final String? rationale;
  final DateTime? createdAt;

  const GoalVersionModel({
    required this.id,
    required this.goalId,
    required this.userId,
    required this.version,
    required this.targetValue,
    required this.startingValue,
    this.weeklyRate,
    required this.startDate,
    this.targetDate,
    this.rationale,
    this.createdAt,
  });

  factory GoalVersionModel.fromJson(Map<String, dynamic> json) {
    return GoalVersionModel(
      id: json['id'] as String,
      goalId: json['goalId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      version: (json['version'] as num).toInt(),
      targetValue: (json['targetValue'] as num).toDouble(),
      startingValue: (json['startingValue'] as num).toDouble(),
      weeklyRate: (json['weeklyRate'] as num?)?.toDouble(),
      startDate: json['startDate'] as String,
      targetDate: json['targetDate'] as String?,
      rationale: json['rationale'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}

/// Matches `Goal` in backend/src/modules/goals/contracts.ts.
///
/// The backend returns `goalType` (not `type`) and nests
/// target/starting values under `currentVersion` — there is no flat
/// `targetValue`/`baselineValue`/`ratePerWeek` on the goal object.
class GoalModel {
  final String id;
  final String userId;

  /// 'weight_loss' | 'muscle_gain' | 'maintenance' | 'general_fitness'
  final String goalType;
  final String targetMetricTypeCode;
  final bool isPrimary;

  /// 'active' | 'achieved' | 'abandoned' | 'superseded'
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final GoalVersionModel? currentVersion;

  /// Progress enrichment added by GoalsService (0-100). Null when absent.
  final double? progressPct;
  final double? currentValue;

  const GoalModel({
    required this.id,
    required this.userId,
    required this.goalType,
    required this.targetMetricTypeCode,
    required this.isPrimary,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.currentVersion,
    this.progressPct,
    this.currentValue,
  });

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    return GoalModel(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? '',
      goalType: json['goalType'] as String,
      targetMetricTypeCode: json['targetMetricTypeCode'] as String? ?? '',
      isPrimary: json['isPrimary'] as bool,
      status: json['status'] as String,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      currentVersion: json['currentVersion'] is Map<String, dynamic>
          ? GoalVersionModel.fromJson(json['currentVersion'] as Map<String, dynamic>)
          : null,
      progressPct: (json['progressPct'] as num?)?.toDouble(),
      currentValue: (json['currentValue'] as num?)?.toDouble(),
    );
  }
}
