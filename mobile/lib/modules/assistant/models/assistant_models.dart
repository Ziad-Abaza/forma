enum EvidenceBadgeType {
  retrieved,
  calculated,
  estimated,
  inferred,
  recommended,
  unknown;

  static EvidenceBadgeType fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'retrieved':
        return EvidenceBadgeType.retrieved;
      case 'calculated':
        return EvidenceBadgeType.calculated;
      case 'estimated':
        return EvidenceBadgeType.estimated;
      case 'inferred':
        return EvidenceBadgeType.inferred;
      case 'recommended':
        return EvidenceBadgeType.recommended;
      default:
        return EvidenceBadgeType.unknown;
    }
  }

  String toBackendString() => name;
}

class EvidenceClaimModel {
  final String claimText;
  final EvidenceBadgeType type;
  final String? source;
  final dynamic value;

  const EvidenceClaimModel({
    required this.claimText,
    required this.type,
    this.source,
    this.value,
  });

  factory EvidenceClaimModel.fromJson(Map<String, dynamic> json) {
    return EvidenceClaimModel(
      claimText: json['claimText'] as String? ?? '',
      type: EvidenceBadgeType.fromString(json['evidenceType'] as String? ?? json['type'] as String?),
      source: json['source'] as String?,
      value: json['value'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'claimText': claimText,
      'evidenceType': type.toBackendString(),
      if (source != null) 'source': source,
      if (value != null) 'value': value,
    };
  }
}

class MetricTileModel {
  final String label;
  final double value;
  final String? unit;
  final double? delta;
  final String? period;
  final EvidenceBadgeType evidence;
  final String size; // 'sm' or 'wide'

  const MetricTileModel({
    required this.label,
    required this.value,
    this.unit,
    this.delta,
    this.period,
    required this.evidence,
    this.size = 'sm',
  });

  factory MetricTileModel.fromJson(Map<String, dynamic> json) {
    return MetricTileModel(
      label: json['label'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String?,
      delta: (json['delta'] as num?)?.toDouble(),
      period: json['period'] as String?,
      evidence: EvidenceBadgeType.fromString(json['evidence'] as String?),
      size: json['size'] as String? ?? 'sm',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'value': value,
      if (unit != null) 'unit': unit,
      if (delta != null) 'delta': delta,
      if (period != null) 'period': period,
      'evidence': evidence.toBackendString(),
      'size': size,
    };
  }
}

class FormaMetricsModel {
  final List<MetricTileModel> tiles;

  const FormaMetricsModel({required this.tiles});

  factory FormaMetricsModel.fromJson(Map<String, dynamic> json) {
    final rawTiles = json['tiles'] as List<dynamic>? ?? [];
    return FormaMetricsModel(
      tiles: rawTiles
          .map((t) => MetricTileModel.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }
}

class FormaSuggestionsModel {
  final List<String> items;

  List<String> get chips => items;

  const FormaSuggestionsModel({required this.items});

  factory FormaSuggestionsModel.fromJson(Map<String, dynamic> json) {
    final raw = (json['chips'] ?? json['items']) as List<dynamic>? ?? [];
    return FormaSuggestionsModel(
      items: raw.map((e) => e.toString()).toList(),
    );
  }
}

class ActionProposalModel {
  final String id;
  final String actionType;
  final String humanReadableSummary;
  final String? diffBefore;
  final String diffAfter;
  final String status; // 'pending', 'confirming', 'confirmed', 'declined', 'expired', 'executed', 'failed'
  final String? receiptId;
  final Map<String, dynamic>? parameters;
  final String? errorMessage;

  const ActionProposalModel({
    required this.id,
    required this.actionType,
    required this.humanReadableSummary,
    this.diffBefore,
    required this.diffAfter,
    this.status = 'pending',
    this.receiptId,
    this.parameters,
    this.errorMessage,
  });

  ActionProposalModel copyWith({
    String? id,
    String? actionType,
    String? humanReadableSummary,
    String? diffBefore,
    String? diffAfter,
    String? status,
    String? receiptId,
    Map<String, dynamic>? parameters,
    String? errorMessage,
  }) {
    return ActionProposalModel(
      id: id ?? this.id,
      actionType: actionType ?? this.actionType,
      humanReadableSummary: humanReadableSummary ?? this.humanReadableSummary,
      diffBefore: diffBefore ?? this.diffBefore,
      diffAfter: diffAfter ?? this.diffAfter,
      status: status ?? this.status,
      receiptId: receiptId ?? this.receiptId,
      parameters: parameters ?? this.parameters,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  factory ActionProposalModel.fromJson(Map<String, dynamic> json) {
    String? beforeStr;
    String afterStr = '';

    if (json['diffPreview'] is Map) {
      final diff = json['diffPreview'] as Map<String, dynamic>;
      if (diff['before'] != null) {
        final b = diff['before'];
        beforeStr = b is Map ? (b['description'] ?? b['value']?.toString() ?? b.toString()) : b.toString();
      }
      if (diff['after'] != null) {
        final a = diff['after'];
        afterStr = a is Map ? (a['description'] ?? '${a['value'] ?? ''} ${a['unit'] ?? ''}'.trim()) : a.toString();
      }
    } else {
      beforeStr = json['diffBefore'] as String?;
      afterStr = json['diffAfter'] as String? ?? '';
    }

    final receipt = json['receipt'] is Map ? json['receipt'] as Map<String, dynamic> : null;

    return ActionProposalModel(
      id: json['id'] as String? ?? '',
      actionType: json['actionType'] as String? ?? 'log_measurement',
      humanReadableSummary: json['humanReadableSummary'] as String? ?? '',
      diffBefore: beforeStr,
      diffAfter: afterStr,
      status: json['status'] as String? ?? 'pending',
      receiptId: receipt != null ? receipt['receiptId'] as String? : json['receiptId'] as String?,
      parameters: json['parameters'] is Map<String, dynamic> ? json['parameters'] as Map<String, dynamic> : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'actionType': actionType,
      'humanReadableSummary': humanReadableSummary,
      if (diffBefore != null) 'diffBefore': diffBefore,
      'diffAfter': diffAfter,
      'status': status,
      if (receiptId != null) 'receiptId': receiptId,
    };
  }
}

class ActionReceiptModel {
  final String receiptId;
  final String proposalId;
  final String actionType;
  final String committedAt;
  final String entityId;
  final String entityType;
  final String provenance;
  final String summary;

  const ActionReceiptModel({
    required this.receiptId,
    required this.proposalId,
    required this.actionType,
    required this.committedAt,
    required this.entityId,
    required this.entityType,
    required this.provenance,
    required this.summary,
  });

  factory ActionReceiptModel.fromJson(Map<String, dynamic> json) {
    return ActionReceiptModel(
      receiptId: json['receiptId'] as String? ?? '',
      proposalId: json['proposalId'] as String? ?? '',
      actionType: json['actionType'] as String? ?? '',
      committedAt: json['committedAt'] as String? ?? '',
      entityId: json['entityId'] as String? ?? '',
      entityType: json['entityType'] as String? ?? '',
      provenance: json['provenance'] as String? ?? 'assistant_proposal',
      summary: json['summary'] as String? ?? '',
    );
  }
}

class AssistantChatMessage {
  final String id;
  final String role; // 'user' or 'assistant'
  final String content;
  final List<EvidenceClaimModel> evidenceClaims;
  final List<ActionProposalModel> proposals;
  final FormaMetricsModel? metricsBlock;
  final FormaSuggestionsModel? suggestionsBlock;
  final bool isEmergencyNotice;
  final bool isInterrupted;
  final String? errorCode; // e.g. S01-S08
  final DateTime timestamp;

  const AssistantChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.evidenceClaims = const [],
    this.proposals = const [],
    this.metricsBlock,
    this.suggestionsBlock,
    this.isEmergencyNotice = false,
    this.isInterrupted = false,
    this.errorCode,
    required this.timestamp,
  });

  AssistantChatMessage copyWith({
    String? id,
    String? role,
    String? content,
    List<EvidenceClaimModel>? evidenceClaims,
    List<ActionProposalModel>? proposals,
    FormaMetricsModel? metricsBlock,
    FormaSuggestionsModel? suggestionsBlock,
    bool? isEmergencyNotice,
    bool? isInterrupted,
    String? errorCode,
    DateTime? timestamp,
  }) {
    return AssistantChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      evidenceClaims: evidenceClaims ?? this.evidenceClaims,
      proposals: proposals ?? this.proposals,
      metricsBlock: metricsBlock ?? this.metricsBlock,
      suggestionsBlock: suggestionsBlock ?? this.suggestionsBlock,
      isEmergencyNotice: isEmergencyNotice ?? this.isEmergencyNotice,
      isInterrupted: isInterrupted ?? this.isInterrupted,
      errorCode: errorCode ?? this.errorCode,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

/// A persisted conversation row as returned by
/// GET /api/v1/assistant/conversations.
class ConversationSummary {
  final String id;
  final String title;
  final String? summary;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ConversationSummary({
    required this.id,
    required this.title,
    this.summary,
    this.createdAt,
    this.updatedAt,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    return ConversationSummary(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}

/// A persisted message row from GET /api/v1/assistant/conversations/:id.
/// Roles can be 'user', 'assistant', 'system' or 'tool' — callers that
/// render chat should filter to the visible roles.
class ConversationMessageModel {
  final String id;
  final String role;
  final String content;
  final List<EvidenceClaimModel> evidenceClaims;
  final List<ActionProposalModel> proposals;
  final String? safetyCategory;
  final DateTime? createdAt;

  const ConversationMessageModel({
    required this.id,
    required this.role,
    required this.content,
    this.evidenceClaims = const [],
    this.proposals = const [],
    this.safetyCategory,
    this.createdAt,
  });

  factory ConversationMessageModel.fromJson(Map<String, dynamic> json) {
    final evidenceList = <EvidenceClaimModel>[];
    if (json['evidenceClaims'] is List) {
      for (final e in json['evidenceClaims'] as List) {
        if (e is Map<String, dynamic>) {
          evidenceList.add(EvidenceClaimModel.fromJson(e));
        }
      }
    }

    final proposalsList = <ActionProposalModel>[];
    if (json['proposals'] is List) {
      for (final p in json['proposals'] as List) {
        if (p is Map<String, dynamic>) {
          proposalsList.add(ActionProposalModel.fromJson(p));
        }
      }
    }

    return ConversationMessageModel(
      id: json['id'] as String? ?? '',
      role: json['role'] as String? ?? 'assistant',
      content: json['content'] as String? ?? '',
      evidenceClaims: evidenceList,
      proposals: proposalsList,
      safetyCategory: json['safetyCategory'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }
}

/// A conversation plus its messages, as returned by
/// GET /api/v1/assistant/conversations/:id.
class ConversationDetail {
  final ConversationSummary conversation;
  final List<ConversationMessageModel> messages;

  const ConversationDetail({
    required this.conversation,
    required this.messages,
  });

  factory ConversationDetail.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'] as List<dynamic>? ?? [];
    return ConversationDetail(
      conversation: ConversationSummary.fromJson(json),
      messages: rawMessages
          .whereType<Map<String, dynamic>>()
          .map(ConversationMessageModel.fromJson)
          .toList(),
    );
  }
}

/// A durable assistant memory row (GET /api/v1/assistant/memories).
/// Category is one of: preference | fact | routine | constraint.
class AssistantMemory {
  final String id;
  final String category;
  final String key;
  final String value;
  final double confidence;
  final String source;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AssistantMemory({
    required this.id,
    required this.category,
    required this.key,
    required this.value,
    this.confidence = 1.0,
    this.source = '',
    this.createdAt,
    this.updatedAt,
  });

  factory AssistantMemory.fromJson(Map<String, dynamic> json) {
    return AssistantMemory(
      id: json['id'] as String? ?? '',
      category: json['category'] as String? ?? 'fact',
      key: json['key'] as String? ?? '',
      value: json['value'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      source: json['source'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}
