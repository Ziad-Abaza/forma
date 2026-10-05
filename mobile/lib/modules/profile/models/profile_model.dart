class ProfileModel {
  final String userId;
  final String dateOfBirth;

  /// Nullable: absent on the backend means unset — never invent a value.
  final String? sexForCalculation;
  final double? heightCm;
  final String? activityLevel;
  final String? experienceLevel;
  final List<String> constraints;
  final Map<String, dynamic> preferences;
  final DateTime? updatedAt;

  const ProfileModel({
    required this.userId,
    required this.dateOfBirth,
    this.sexForCalculation,
    this.heightCm,
    this.activityLevel,
    this.experienceLevel,
    this.constraints = const [],
    this.preferences = const {},
    this.updatedAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      userId: json['userId'] as String? ?? '',
      dateOfBirth: json['dateOfBirth'] as String? ?? '',
      sexForCalculation: json['sexForCalculation'] as String?,
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      activityLevel: json['activityLevel'] as String?,
      experienceLevel: json['experienceLevel'] as String?,
      constraints: (json['constraints'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      preferences: (json['preferences'] as Map<String, dynamic>?) ?? {},
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'heightCm': heightCm,
      'sexForCalculation': sexForCalculation,
      'activityLevel': activityLevel,
      'experienceLevel': experienceLevel,
      'constraints': constraints,
    };
  }
}

class ProfileHistoryItem {
  final String id;
  final String attributeName;
  final dynamic oldValue;
  final dynamic newValue;
  final DateTime? effectiveFrom;
  final String? actor;

  const ProfileHistoryItem({
    required this.id,
    required this.attributeName,
    this.oldValue,
    this.newValue,
    this.effectiveFrom,
    this.actor,
  });

  factory ProfileHistoryItem.fromJson(Map<String, dynamic> json) {
    return ProfileHistoryItem(
      id: json['id'] as String? ?? '',
      attributeName: json['attributeName'] as String? ?? json['attribute_name'] as String? ?? '',
      oldValue: json['oldValue'] ?? json['old_value'],
      newValue: json['newValue'] ?? json['new_value'],
      effectiveFrom: DateTime.tryParse(json['effectiveFrom']?.toString() ?? json['effective_from']?.toString() ?? ''),
      actor: json['actor'] as String?,
    );
  }
}
