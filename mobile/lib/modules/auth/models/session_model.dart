/// Represents a single authenticated session (refresh-token family) as
/// returned by GET /api/v1/auth/sessions.
class SessionInfo {
  final String id;
  final Map<String, dynamic> deviceInfo;
  final String? familyId;

  /// Nullable fields stay nullable — a missing backend value is unknown,
  /// never fabricated.
  final bool? isRevoked;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  const SessionInfo({
    required this.id,
    this.deviceInfo = const {},
    this.familyId,
    this.isRevoked,
    this.expiresAt,
    this.createdAt,
  });

  bool get isActive => isRevoked == false;

  /// Short human summary of device_info, e.g. "android • pixel_8".
  /// Returns empty string when nothing useful is present.
  String get deviceSummary {
    final parts = <String?>[
      deviceInfo['platform']?.toString(),
      deviceInfo['device']?.toString(),
      deviceInfo['model']?.toString(),
      deviceInfo['os']?.toString(),
      deviceInfo['browser']?.toString(),
    ]
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    return parts.join(' • ');
  }

  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    final rawDevice = json['deviceInfo'] ?? json['device_info'];
    return SessionInfo(
      id: json['id']?.toString() ?? '',
      deviceInfo: rawDevice is Map
          ? rawDevice.map((k, v) => MapEntry(k.toString(), v))
          : const {},
      familyId: (json['familyId'] ?? json['family_id'])?.toString(),
      isRevoked: (json['isRevoked'] ?? json['is_revoked']) as bool?,
      expiresAt: DateTime.tryParse(
          (json['expiresAt'] ?? json['expires_at'])?.toString() ?? ''),
      createdAt: DateTime.tryParse(
          (json['createdAt'] ?? json['created_at'])?.toString() ?? ''),
    );
  }
}
