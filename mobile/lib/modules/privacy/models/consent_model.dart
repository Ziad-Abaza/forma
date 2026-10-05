/// A single consent record as returned by GET /api/v1/privacy/consents.
class ConsentInfo {
  /// e.g. 'terms_of_service', 'health_data_processing', 'ai_third_party_processing'
  final String policyType;
  final String? version;

  /// Nullable: a missing flag means unknown, not granted.
  final bool? granted;
  final DateTime? grantedAt;
  final DateTime? withdrawnAt;

  const ConsentInfo({
    required this.policyType,
    this.version,
    this.granted,
    this.grantedAt,
    this.withdrawnAt,
  });

  /// Consent is currently in effect: granted and not withdrawn.
  bool get isActive => granted == true && withdrawnAt == null;

  /// Only third-party AI processing can be withdrawn while the account
  /// is active; terms/health-data consents require account deletion.
  bool get isWithdrawable => policyType == 'ai_third_party_processing';

  factory ConsentInfo.fromJson(Map<String, dynamic> json) {
    return ConsentInfo(
      policyType: (json['policyType'] ?? json['policy_type'])?.toString() ?? '',
      version: json['version']?.toString(),
      granted: json['granted'] as bool?,
      grantedAt: DateTime.tryParse(
          (json['grantedAt'] ?? json['granted_at'])?.toString() ?? ''),
      withdrawnAt: DateTime.tryParse(
          (json['withdrawnAt'] ?? json['withdrawn_at'])?.toString() ?? ''),
    );
  }
}
