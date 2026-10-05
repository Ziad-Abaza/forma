import 'dart:convert';
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

class SSEEvent {
  final String event;
  final Map<String, dynamic> data;

  const SSEEvent({required this.event, required this.data});
}

class AssistantRepository {
  final ApiClient apiClient;

  AssistantRepository({required this.apiClient});

  /// Streams assistant SSE responses natively (Spec §6.2)
  Stream<SSEEvent> streamMessage({
    required String message,
    String? conversationId,
  }) async* {
    final body = <String, dynamic>{
      'message': message,
      'stream': true,
    };
    if (conversationId != null) {
      body['conversationId'] = conversationId;
    }

    String currentEvent = 'message';

    await for (final line in apiClient.sendStream('/api/v1/assistant/chat', body: body)) {
      if (line.startsWith('event: ')) {
        currentEvent = line.substring(7).trim();
      } else if (line.startsWith('data: ')) {
        final dataStr = line.substring(6).trim();
        try {
          final parsed = jsonDecode(dataStr);
          if (parsed is Map<String, dynamic>) {
            yield SSEEvent(event: currentEvent, data: parsed);
          }
        } catch (_) {}
      }
    }
  }

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
    // No fabricated IDs: absent server id stays an empty string (never a
    // timestamp-fake). Backend always returns assistantMessageId today.
    final assistantMsgId = map['assistantMessageId'] as String? ?? '';
    final content = map['content'] as String? ?? '';
    // Nullable: missing category means unknown, not 'A' (safe). Only an
    // explicit 'D' flags an emergency notice.
    final safetyCategory = map['safetyCategory'] as String?;
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

    FormaMetricsModel? metricsBlock;
    if (map['metricsBlock'] is Map<String, dynamic>) {
      metricsBlock = FormaMetricsModel.fromJson(map['metricsBlock'] as Map<String, dynamic>);
    }

    FormaSuggestionsModel? suggestionsBlock;
    if (map['suggestionsBlock'] is Map<String, dynamic>) {
      suggestionsBlock = FormaSuggestionsModel.fromJson(map['suggestionsBlock'] as Map<String, dynamic>);
    }

    final assistantMsg = AssistantChatMessage(
      id: assistantMsgId,
      role: 'assistant',
      content: content,
      evidenceClaims: evidenceList,
      proposals: proposalsList,
      metricsBlock: metricsBlock,
      suggestionsBlock: suggestionsBlock,
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

  /// Lists the user's persisted conversations, most recently active first.
  /// Response shape: { conversations: Conversation[] }
  Future<List<ConversationSummary>> listConversations() async {
    final resp = await apiClient.get('/api/v1/assistant/conversations');
    final map = resp is Map<String, dynamic> ? resp : <String, dynamic>{};
    final raw = map['conversations'] as List<dynamic>? ?? [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ConversationSummary.fromJson)
        .toList();
  }

  /// Fetches a conversation and its messages (chronological order) for
  /// history restore. Throws [ApiException] 404 when the conversation
  /// no longer exists.
  Future<ConversationDetail> getConversation(String id) async {
    final resp = await apiClient.get('/api/v1/assistant/conversations/$id');
    final map = resp is Map<String, dynamic> ? resp : <String, dynamic>{};
    return ConversationDetail.fromJson(map);
  }

  /// Deletes a conversation (server cascades its messages).
  /// Returns the server-reported success flag.
  Future<bool> deleteConversation(String id) async {
    final resp = await apiClient.delete('/api/v1/assistant/conversations/$id');
    return resp is Map<String, dynamic> && resp['success'] == true;
  }

  /// Lists the user's active durable memories.
  /// Response shape: { memories: AssistantMemory[] }
  Future<List<AssistantMemory>> listMemories() async {
    final resp = await apiClient.get('/api/v1/assistant/memories');
    final map = resp is Map<String, dynamic> ? resp : <String, dynamic>{};
    final raw = map['memories'] as List<dynamic>? ?? [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(AssistantMemory.fromJson)
        .toList();
  }

  /// Creates (or upserts on category+key) a durable memory.
  /// Category must be one of: preference | fact | routine | constraint.
  Future<AssistantMemory> createMemory({
    required String category,
    required String key,
    required String value,
  }) async {
    final resp = await apiClient.post(
      '/api/v1/assistant/memories',
      body: {
        'category': category,
        'key': key,
        'value': value,
      },
    );
    final map = resp is Map<String, dynamic> ? resp : <String, dynamic>{};
    final memMap = (map['memory'] is Map)
        ? map['memory'] as Map<String, dynamic>
        : map;
    return AssistantMemory.fromJson(memMap);
  }

  /// Soft-deletes a memory. Returns the server-reported success flag.
  Future<bool> deleteMemory(String id) async {
    final resp = await apiClient.delete('/api/v1/assistant/memories/$id');
    return resp is Map<String, dynamic> && resp['success'] == true;
  }
}

final assistantRepositoryProvider = Provider<AssistantRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AssistantRepository(apiClient: apiClient);
});
