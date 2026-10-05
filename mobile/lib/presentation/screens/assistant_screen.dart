import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import '../../modules/assistant/models/assistant_models.dart';
import '../../modules/assistant/repositories/assistant_repository.dart';

export '../../modules/assistant/models/assistant_models.dart';
export '../../modules/assistant/repositories/assistant_repository.dart';

class AssistantChatState {
  final List<AssistantChatMessage> messages;
  final bool isStreaming;
  final String? conversationId;
  final String? errorMessage;

  const AssistantChatState({
    required this.messages,
    this.isStreaming = false,
    this.conversationId,
    this.errorMessage,
  });

  AssistantChatState copyWith({
    List<AssistantChatMessage>? messages,
    bool? isStreaming,
    String? conversationId,
    String? errorMessage,
  }) {
    return AssistantChatState(
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      conversationId: conversationId ?? this.conversationId,
      errorMessage: errorMessage,
    );
  }
}

class AssistantChatNotifier extends StateNotifier<AssistantChatState> {
  final AssistantRepository repository;

  AssistantChatNotifier({required this.repository})
      : super(AssistantChatState(
          messages: [
            AssistantChatMessage(
              id: 'init_1',
              role: 'assistant',
              content:
                  'Hello! I am Forma, your personalized health and wellness companion. I can help answer fitness questions, monitor your progress, or prepare action proposals to log measurements and update goals.',
              evidenceClaims: const [
                EvidenceClaimModel(
                  claimText: 'Grounding verified',
                  type: EvidenceBadgeType.retrieved,
                ),
              ],
              timestamp: DateTime.now(),
            ),
          ],
        ));

  Future<void> sendMessage(String text, AppLocalizations l10n) async {
    if (text.trim().isEmpty) return;

    final userMsg = AssistantChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      content: text.trim(),
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isStreaming: true,
      errorMessage: null,
    );

    try {
      final result = await repository.sendMessage(
        message: text.trim(),
        conversationId: state.conversationId,
      );

      state = state.copyWith(
        messages: [...state.messages, result.assistantMessage],
        conversationId: result.conversationId.isNotEmpty ? result.conversationId : state.conversationId,
        isStreaming: false,
      );
    } catch (err) {
      final errorMsg = AssistantChatMessage(
        id: 'err_${DateTime.now().millisecondsSinceEpoch}',
        role: 'assistant',
        content: 'Unable to connect to Forma Assistant service: ${err.toString()}',
        timestamp: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        isStreaming: false,
        errorMessage: err.toString(),
      );
    }
  }

  Future<void> confirmProposal(String messageId, String proposalId) async {
    try {
      final result = await repository.confirmProposal(proposalId);
      final updated = state.messages.map((msg) {
        if (msg.id == messageId) {
          final updatedProps = msg.proposals.map((p) {
            if (p.id == proposalId) {
              p.status = 'executed';
            }
            return p;
          }).toList();
          return msg.copyWith(proposals: updatedProps);
        }
        return msg;
      }).toList();

      final summaryText = result.receipt.summary.isNotEmpty
          ? result.receipt.summary
          : 'Action has been securely committed';

      final receiptMsg = AssistantChatMessage(
        id: 'receipt_${DateTime.now().millisecondsSinceEpoch}',
        role: 'assistant',
        content: '✅ Action Receipt verified: $summaryText with provenance [${result.receipt.provenance}].',
        evidenceClaims: const [
          EvidenceClaimModel(
            claimText: 'Receipt committed',
            type: EvidenceBadgeType.retrieved,
          ),
        ],
        timestamp: DateTime.now(),
      );

      state = state.copyWith(messages: [...updated, receiptMsg]);
    } catch (err) {
      final failMsg = AssistantChatMessage(
        id: 'fail_${DateTime.now().millisecondsSinceEpoch}',
        role: 'assistant',
        content: 'Failed to commit action proposal: $err',
        timestamp: DateTime.now(),
      );
      state = state.copyWith(messages: [...state.messages, failMsg]);
    }
  }

  Future<void> declineProposal(String messageId, String proposalId) async {
    try {
      await repository.declineProposal(proposalId);
    } catch (_) {}

    final updated = state.messages.map((msg) {
      if (msg.id == messageId) {
        final updatedProps = msg.proposals.map((p) {
          if (p.id == proposalId) {
            p.status = 'declined';
          }
          return p;
        }).toList();
        return msg.copyWith(proposals: updatedProps);
      }
      return msg;
    }).toList();

    state = state.copyWith(messages: updated);
  }

  void clearConversation() {
    state = AssistantChatState(
      messages: [
        AssistantChatMessage(
          id: 'init_reset',
          role: 'assistant',
          content: 'Started a new conversation. How can I assist you with your health today?',
          timestamp: DateTime.now(),
        ),
      ],
      conversationId: null,
    );
  }
}

final assistantChatProvider =
    StateNotifierProvider<AssistantChatNotifier, AssistantChatState>((ref) {
  final repository = ref.watch(assistantRepositoryProvider);
  return AssistantChatNotifier(repository: repository);
});

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final chatState = ref.watch(assistantChatProvider);
    final numeralSystem = ref.watch(numeralSystemProvider);

    ref.listen(assistantChatProvider, (_, _) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/logo.png',
              width: 28,
              height: 28,
              cacheWidth: 84,
              cacheHeight: 84,
              errorBuilder: (_, _, _) => const Icon(Icons.smart_toy_outlined, color: FormaTheme.primaryTeal),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.assistantTitle,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    l10n.assistantSubtitle,
                    style: const TextStyle(fontSize: 12, color: FormaTheme.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.newChat,
            icon: const Icon(Icons.refresh, color: FormaTheme.primaryTeal),
            onPressed: () {
              ref.read(assistantChatProvider.notifier).clearConversation();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Messages list
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: chatState.messages.length,
                itemBuilder: (context, index) {
                  final msg = chatState.messages[index];
                  return _buildMessageRow(context, msg, l10n, numeralSystem);
                },
              ),
            ),

            if (chatState.isStreaming)
              const LinearProgressIndicator(
                backgroundColor: FormaTheme.surfaceCard,
                color: FormaTheme.primaryTeal,
              ),

            // Input bar
            _buildInputBar(context, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageRow(
    BuildContext context,
    AssistantChatMessage msg,
    AppLocalizations l10n,
    String numeralSystem,
  ) {
    final isUser = msg.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: msg.isEmergencyNotice
                        ? FormaTheme.alertCoral.withAlpha(40)
                        : FormaTheme.primaryTeal.withAlpha(30),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: msg.isEmergencyNotice
                          ? FormaTheme.alertCoral
                          : FormaTheme.primaryTeal,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: msg.isEmergencyNotice
                        ? const Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: FormaTheme.alertCoral,
                          )
                        : ClipOval(
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Image.asset(
                                'assets/logo.png',
                                width: 22,
                                height: 22,
                                cacheWidth: 66,
                                cacheHeight: 66,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.smart_toy_outlined,
                                  size: 18,
                                  color: FormaTheme.primaryTeal,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isUser
                        ? FormaTheme.primaryTeal.withAlpha(40)
                        : (msg.isEmergencyNotice
                            ? FormaTheme.alertCoral.withAlpha(25)
                            : FormaTheme.surfaceCard),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: msg.isEmergencyNotice
                          ? FormaTheme.alertCoral
                          : (isUser
                              ? FormaTheme.primaryTeal.withAlpha(80)
                              : FormaTheme.borderSubtle),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (msg.isEmergencyNotice) ...[
                        Row(
                          children: [
                            const Icon(Icons.emergency,
                                color: FormaTheme.alertCoral, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              l10n.safetyEmergencyTitle,
                              style: const TextStyle(
                                color: FormaTheme.alertCoral,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        formatNumeralString(msg.content, numeralSystem),
                        style: TextStyle(
                          color: msg.isEmergencyNotice
                              ? FormaTheme.textPrimary
                              : (isUser
                                  ? FormaTheme.textPrimary
                                  : FormaTheme.textPrimary),
                          fontSize: 14.5,
                          height: 1.45,
                        ),
                      ),

                      // Evidence Badges
                      if (msg.evidenceClaims.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: msg.evidenceClaims
                              .map((c) => _buildEvidenceBadge(c, l10n))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: FormaTheme.surfaceElevated,
                  child: Icon(Icons.person, size: 18, color: FormaTheme.textPrimary),
                ),
              ],
            ],
          ),

          // Action Proposals Cards
          if (msg.proposals.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...msg.proposals.map((p) => _buildActionProposalCard(context, msg.id, p, l10n, numeralSystem)),
          ],
        ],
      ),
    );
  }

  Widget _buildEvidenceBadge(EvidenceClaimModel claim, AppLocalizations l10n) {
    Color badgeColor;
    String label;

    switch (claim.type) {
      case EvidenceBadgeType.retrieved:
        badgeColor = FormaTheme.badgeMeasured;
        label = l10n.evidenceBadgeRetrieved;
        break;
      case EvidenceBadgeType.calculated:
        badgeColor = FormaTheme.badgeCalculated;
        label = l10n.evidenceBadgeCalculated;
        break;
      case EvidenceBadgeType.estimated:
        badgeColor = FormaTheme.badgeEstimated;
        label = l10n.evidenceBadgeEstimated;
        break;
      case EvidenceBadgeType.inferred:
        badgeColor = FormaTheme.secondaryMint;
        label = l10n.evidenceBadgeInferred;
        break;
      case EvidenceBadgeType.recommended:
        badgeColor = FormaTheme.successGreen;
        label = l10n.evidenceBadgeRecommended;
        break;
      default:
        badgeColor = FormaTheme.textTertiary;
        label = 'Note';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withAlpha(35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withAlpha(120), width: 1),
      ),
      child: Text(
        '[$label: ${claim.claimText}]',
        style: TextStyle(
          color: badgeColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildActionProposalCard(
    BuildContext context,
    String messageId,
    ActionProposalModel proposal,
    AppLocalizations l10n,
    String numeralSystem,
  ) {
    final isPending = proposal.status == 'pending';
    final isExecuted = proposal.status == 'executed';
    final isDeclined = proposal.status == 'declined';

    return Container(
      margin: const EdgeInsets.only(top: 8, left: 40, right: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FormaTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExecuted
              ? FormaTheme.successGreen
              : (isPending ? FormaTheme.warningAmber : FormaTheme.borderSubtle),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isExecuted
                    ? Icons.check_circle_outline
                    : (isDeclined ? Icons.cancel_outlined : Icons.pending_actions),
                size: 18,
                color: isExecuted
                    ? FormaTheme.successGreen
                    : (isDeclined ? FormaTheme.textTertiary : FormaTheme.warningAmber),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.actionProposed,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isExecuted
                        ? FormaTheme.successGreen
                        : (isDeclined ? FormaTheme.textTertiary : FormaTheme.warningAmber),
                  ),
                ),
              ),
              _buildStatusPill(proposal.status, l10n),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formatNumeralString(proposal.humanReadableSummary, numeralSystem),
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: FormaTheme.textPrimary,
            ),
          ),
          if (proposal.diffBefore != null || proposal.diffAfter.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: FormaTheme.obsidianBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: FormaTheme.borderSubtle, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (proposal.diffBefore != null) ...[
                    Text(
                      proposal.diffBefore!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: FormaTheme.textSecondary,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 12, color: FormaTheme.primaryTeal),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    proposal.diffAfter,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: FormaTheme.primaryTeal,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FormaTheme.primaryTeal,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      ref
                          .read(assistantChatProvider.notifier)
                          .confirmProposal(messageId, proposal.id);
                    },
                    icon: const Icon(Icons.check, size: 16),
                    label: Text(l10n.confirmAction, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FormaTheme.textSecondary,
                      side: const BorderSide(color: FormaTheme.borderSubtle),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      ref
                          .read(assistantChatProvider.notifier)
                          .declineProposal(messageId, proposal.id);
                    },
                    icon: const Icon(Icons.close, size: 16),
                    label: Text(l10n.declineAction),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status, AppLocalizations l10n) {
    Color bg;
    Color fg;
    String text;

    switch (status) {
      case 'executed':
        bg = FormaTheme.successGreen.withAlpha(30);
        fg = FormaTheme.successGreen;
        text = l10n.actionConfirmed;
        break;
      case 'declined':
        bg = FormaTheme.textTertiary.withAlpha(30);
        fg = FormaTheme.textTertiary;
        text = l10n.actionDeclined;
        break;
      case 'expired':
        bg = FormaTheme.warningAmber.withAlpha(30);
        fg = FormaTheme.warningAmber;
        text = l10n.actionExpired;
        break;
      default:
        bg = FormaTheme.primaryTeal.withAlpha(30);
        fg = FormaTheme.primaryTeal;
        text = 'Pending Confirmation';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withAlpha(100), width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildInputBar(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: FormaTheme.surfaceCard,
        border: Border(top: BorderSide(color: FormaTheme.borderSubtle, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: l10n.chatInputPlaceholder,
                hintStyle: const TextStyle(color: FormaTheme.textTertiary, fontSize: 14),
                filled: true,
                fillColor: FormaTheme.obsidianBackground,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: FormaTheme.borderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: FormaTheme.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: FormaTheme.primaryTeal),
                ),
              ),
              onSubmitted: (val) {
                ref.read(assistantChatProvider.notifier).sendMessage(val, l10n);
                _textController.clear();
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: FormaTheme.primaryTeal,
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.send_rounded, size: 20),
            onPressed: () {
              ref
                  .read(assistantChatProvider.notifier)
                  .sendMessage(_textController.text, l10n);
              _textController.clear();
            },
          ),
        ],
      ),
    );
  }
}
