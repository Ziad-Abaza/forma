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

class ActionProposalModel {
  final String id;
  final String actionType;
  final String humanReadableSummary;
  final String? diffBefore;
  final String diffAfter;
  String status; // 'pending', 'confirmed', 'declined', 'expired', 'executed', 'failed'
  final String? receiptId;
  final Map<String, dynamic>? parameters;

  ActionProposalModel({
    required this.id,
    required this.actionType,
    required this.humanReadableSummary,
    this.diffBefore,
    required this.diffAfter,
    this.status = 'pending',
    this.receiptId,
    this.parameters,
  });

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
  final bool isEmergencyNotice;
  final DateTime timestamp;

  const AssistantChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.evidenceClaims = const [],
    this.proposals = const [],
    this.isEmergencyNotice = false,
    required this.timestamp,
  });

  AssistantChatMessage copyWith({
    String? id,
    String? role,
    String? content,
    List<EvidenceClaimModel>? evidenceClaims,
    List<ActionProposalModel>? proposals,
    bool? isEmergencyNotice,
    DateTime? timestamp,
  }) {
    return AssistantChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      evidenceClaims: evidenceClaims ?? this.evidenceClaims,
      proposals: proposals ?? this.proposals,
      isEmergencyNotice: isEmergencyNotice ?? this.isEmergencyNotice,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
