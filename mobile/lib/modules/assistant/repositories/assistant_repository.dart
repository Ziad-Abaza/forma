import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../models/assistant_models.dart';

class SendMessageResult {
  final String conversationId;
  final AssistantChatMessage assistantMessage;

  const SendMessageResult({
    required this.conversationId,
    required this.assistantMessage,
  });
}

class ConfirmProposalResult {
  final ActionProposalModel proposal;
  final ActionReceiptModel receipt;

  const ConfirmProposalResult({
    required this.proposal,
    required this.receipt,
  });
}

class AssistantRepository {
  final ApiClient apiClient;

  AssistantRepository({required this.apiClient});

  Future<SendMessageResult> sendMessage({
    required String message,
    String? conversationId,
  }) async {
    final body = <String, dynamic>{
      'message': message,
    };
    if (conversationId != null) {
      body['conversationId'] = conversationId;
    }

    final resp = await apiClient.post('/api/v1/assistant/chat', body: body);
    final map = resp as Map<String, dynamic>;

    final convId = map['conversationId'] as String? ?? '';
    final assistantMsgId = map['assistantMessageId'] as String? ?? 'msg_${DateTime.now().millisecondsSinceEpoch}';
    final content = map['content'] as String? ?? '';
    final safetyCategory = map['safetyCategory'] as String? ?? 'A';
    final isEmergency = safetyCategory == 'D';

    final evidenceList = <EvidenceClaimModel>[];
    if (map['evidenceClaims'] is List) {
      for (final e in map['evidenceClaims'] as List) {
        if (e is Map<String, dynamic>) {
          evidenceList.add(EvidenceClaimModel.fromJson(e));
        }
      }
    }

    final proposalsList = <ActionProposalModel>[];
    if (map['proposals'] is List) {
      for (final p in map['proposals'] as List) {
        if (p is Map<String, dynamic>) {
          proposalsList.add(ActionProposalModel.fromJson(p));
        }
      }
    }

    final assistantMsg = AssistantChatMessage(
      id: assistantMsgId,
      role: 'assistant',
      content: content,
      evidenceClaims: evidenceList,
      proposals: proposalsList,
      isEmergencyNotice: isEmergency,
      timestamp: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
    );

    return SendMessageResult(
      conversationId: convId,
      assistantMessage: assistantMsg,
    );
  }

  Future<ConfirmProposalResult> confirmProposal(String proposalId, {String? idempotencyKey}) async {
    final body = <String, dynamic>{};
    if (idempotencyKey != null) {
      body['idempotencyKey'] = idempotencyKey;
    }

    final resp = await apiClient.post('/api/v1/assistant/proposals/$proposalId/confirm', body: body);
    final map = resp as Map<String, dynamic>;

    final propMap = (map['proposal'] is Map) ? map['proposal'] as Map<String, dynamic> : map;
    final receiptMap = (map['receipt'] is Map) ? map['receipt'] as Map<String, dynamic> : <String, dynamic>{};

    return ConfirmProposalResult(
      proposal: ActionProposalModel.fromJson(propMap),
      receipt: ActionReceiptModel.fromJson(receiptMap),
    );
  }

  Future<ActionProposalModel> declineProposal(String proposalId) async {
    final resp = await apiClient.post('/api/v1/assistant/proposals/$proposalId/decline');
    final map = resp as Map<String, dynamic>;
    final propMap = (map['proposal'] is Map) ? map['proposal'] as Map<String, dynamic> : map;
    return ActionProposalModel.fromJson(propMap);
  }
}

final assistantRepositoryProvider = Provider<AssistantRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AssistantRepository(apiClient: apiClient);
});
