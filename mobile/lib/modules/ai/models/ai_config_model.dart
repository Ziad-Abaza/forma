class AICredentialModel {
  final String id;
  final String provider;
  final String keyFingerprint;
  final bool isActive;
  final DateTime? createdAt;

  const AICredentialModel({
    required this.id,
    required this.provider,
    required this.keyFingerprint,
    required this.isActive,
    this.createdAt,
  });

  factory AICredentialModel.fromJson(Map<String, dynamic> json) {
    return AICredentialModel(
      id: json['id'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      keyFingerprint: json['keyFingerprint'] as String? ?? json['key_fingerprint'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? json['is_active'] as bool? ?? true,
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
  final String evalStatus;

  const AIModelItem({
    required this.id,
    required this.provider,
    required this.displayName,
    required this.capabilities,
    required this.evalStatus,
  });

  factory AIModelItem.fromJson(Map<String, dynamic> json) {
    return AIModelItem(
      id: json['id'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      displayName: json['displayName'] as String? ?? json['id'] as String? ?? '',
      capabilities: (json['capabilities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      evalStatus: json['evalStatus'] as String? ?? 'approved',
    );
  }
}

class AIConfigModel {
  final String activeProvider;
  final List<String> availableProviders;
  final List<AIModelItem> models;
  final List<AICredentialModel> credentials;

  const AIConfigModel({
    required this.activeProvider,
    required this.availableProviders,
    required this.models,
    required this.credentials,
  });

  factory AIConfigModel.fromJson(Map<String, dynamic> json) {
    return AIConfigModel(
      activeProvider: json['activeProvider'] as String? ?? 'google',
      availableProviders: (json['availableProviders'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ['google', 'secondary'],
      models: (json['models'] as List<dynamic>?)?.map((e) => AIModelItem.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      credentials: (json['credentials'] as List<dynamic>?)?.map((e) => AICredentialModel.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    );
  }

  bool hasCredentialFor(String provider) {
    return credentials.any((c) => c.provider.toLowerCase() == provider.toLowerCase() && c.isActive);
  }

  AICredentialModel? getCredentialFor(String provider) {
    return credentials.where((c) => c.provider.toLowerCase() == provider.toLowerCase() && c.isActive).firstOrNull;
  }
}
