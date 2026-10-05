class AICredentialModel {
  final String id;
  final String provider;
  final String keyFingerprint;

  /// Nullable: a missing flag means unknown, not active.
  final bool? isActive;
  final DateTime? createdAt;

  const AICredentialModel({
    required this.id,
    required this.provider,
    required this.keyFingerprint,
    this.isActive,
    this.createdAt,
  });

  factory AICredentialModel.fromJson(Map<String, dynamic> json) {
    return AICredentialModel(
      id: json['id'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      keyFingerprint: json['keyFingerprint'] as String? ?? json['key_fingerprint'] as String? ?? '',
      isActive: (json['isActive'] ?? json['is_active']) as bool?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : (json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null),
    );
  }
}

class AIModelItem {
  final String id;
  final String provider;
  final String displayName;
  final List<String> capabilities;

  /// 'approved' | 'candidate' | 'deprecated' — nullable: missing ≠ approved.
  final String? evalStatus;

  const AIModelItem({
    required this.id,
    required this.provider,
    required this.displayName,
    required this.capabilities,
    this.evalStatus,
  });

  factory AIModelItem.fromJson(Map<String, dynamic> json) {
    return AIModelItem(
      id: json['id'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      displayName: json['displayName'] as String? ?? json['id'] as String? ?? '',
      capabilities: (json['capabilities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      evalStatus: json['evalStatus'] as String?,
    );
  }
}

class AIConfigModel {
  /// Nullable: missing means no active provider configured, never invented.
  final String? activeProvider;

  /// Nullable: missing means no preferred model chosen, never invented.
  final String? preferredModel;
  final List<String> availableProviders;
  final List<AIModelItem> models;
  final List<AICredentialModel> credentials;

  const AIConfigModel({
    this.activeProvider,
    this.preferredModel,
    this.availableProviders = const [],
    required this.models,
    required this.credentials,
  });

  factory AIConfigModel.fromJson(Map<String, dynamic> json) {
    // The backend may expose preferences either flat (activeProvider at the
    // top level) or nested under `aiPreferences` — support both honestly.
    final prefs = json['aiPreferences'];
    final prefsMap = prefs is Map<String, dynamic> ? prefs : const <String, dynamic>{};

    return AIConfigModel(
      activeProvider: (prefsMap['activeProvider'] ?? json['activeProvider']) as String?,
      preferredModel: (prefsMap['preferredModel'] ?? json['preferredModel']) as String?,
      availableProviders: (json['availableProviders'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      models: (json['models'] as List<dynamic>?)?.map((e) => AIModelItem.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      credentials: (json['credentials'] as List<dynamic>?)?.map((e) => AICredentialModel.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    );
  }

  /// Models eligible for user selection: those marked 'approved', or the
  /// full list when the backend marks none (avoids an empty picker).
  List<AIModelItem> get selectableModels {
    final approved = models.where((m) => m.evalStatus == 'approved').toList();
    return approved.isNotEmpty ? approved : models;
  }

  bool hasCredentialFor(String provider) {
    return credentials.any((c) => c.provider.toLowerCase() == provider.toLowerCase() && c.isActive == true);
  }

  AICredentialModel? getCredentialFor(String provider) {
    return credentials.where((c) => c.provider.toLowerCase() == provider.toLowerCase() && c.isActive == true).firstOrNull;
  }
}
