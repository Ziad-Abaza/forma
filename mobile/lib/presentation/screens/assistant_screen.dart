import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import '../../modules/assistant/models/assistant_models.dart';
import '../../modules/assistant/repositories/assistant_repository.dart';
import '../widgets/chat/assistant_message_view.dart';
import '../widgets/chat/chat_error_card.dart';
import '../widgets/chat/composer.dart';
import '../widgets/chat/empty_state_bento.dart';
import '../widgets/chat/jump_to_latest_pill.dart';
import '../widgets/chat/typing_indicator.dart';
import '../widgets/chat/user_bubble.dart';

export '../../modules/assistant/models/assistant_models.dart';
export '../../modules/assistant/repositories/assistant_repository.dart';

class AssistantChatState {
  final List<AssistantChatMessage> messages;
  final bool isStreaming;
  final String? streamingStage; // 'retrieving_context' | 'calculating' | 'generating'
  final String? conversationId;
  final String? activeErrorCode; // 'S01' through 'S08'
  final List<String> currentSuggestions;
  final String? lastUserPrompt;

  const AssistantChatState({
    required this.messages,
    this.isStreaming = false,
    this.streamingStage,
    this.conversationId,
    this.activeErrorCode,
    this.currentSuggestions = const [],
    this.lastUserPrompt,
  });

  AssistantChatState copyWith({
    List<AssistantChatMessage>? messages,
    bool? isStreaming,
    String? streamingStage,
    bool clearStreamingStage = false,
    String? conversationId,
    String? activeErrorCode,
    bool clearErrorCode = false,
    List<String>? currentSuggestions,
    String? lastUserPrompt,
  }) {
    return AssistantChatState(
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      streamingStage: clearStreamingStage ? null : (streamingStage ?? this.streamingStage),
      conversationId: conversationId ?? this.conversationId,
      activeErrorCode: clearErrorCode ? null : (activeErrorCode ?? this.activeErrorCode),
      currentSuggestions: currentSuggestions ?? this.currentSuggestions,
      lastUserPrompt: lastUserPrompt ?? this.lastUserPrompt,
    );
  }
}

class AssistantChatNotifier extends StateNotifier<AssistantChatState> {
  final AssistantRepository repository;
  StreamSubscription<SSEEvent>? _streamSubscription;

  AssistantChatNotifier({required this.repository})
      : super(const AssistantChatState(
          messages: [],
        ));

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  void stopStreaming() {
    if (_streamSubscription != null) {
      _streamSubscription?.cancel();
      _streamSubscription = null;
      state = state.copyWith(
        isStreaming: false,
        clearStreamingStage: true,
      );
    }
  }

  Future<void> retryLastPrompt(AppLocalizations l10n) async {
    final prompt = state.lastUserPrompt;
    if (prompt != null && prompt.isNotEmpty) {
      await sendMessage(prompt, l10n);
    }
  }

  Future<void> sendMessage(String text, AppLocalizations l10n) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // Cancel any active stream before starting a new one
    stopStreaming();

    final userMsg = AssistantChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      content: trimmed,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isStreaming: true,
      streamingStage: 'retrieving_context',
      clearErrorCode: true,
      lastUserPrompt: trimmed,
      currentSuggestions: const [],
    );

    // Placeholder for incoming assistant stream
    final assistantMsgId = 'asst_${DateTime.now().millisecondsSinceEpoch}';
    final assistantMsg = AssistantChatMessage(
      id: assistantMsgId,
      role: 'assistant',
      content: '',
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, assistantMsg],
    );

    try {
      final stream = repository.streamMessage(
        message: trimmed,
        conversationId: state.conversationId,
      );

      _streamSubscription = stream.listen(
        (event) {
          _handleSSEEvent(event, assistantMsgId);
        },
        onError: (err) {
          _handleStreamError(err, assistantMsgId);
        },
        onDone: () {
          state = state.copyWith(
            isStreaming: false,
            clearStreamingStage: true,
          );
          _streamSubscription = null;
        },
        cancelOnError: true,
      );
    } catch (err) {
      _handleStreamError(err, assistantMsgId);
    }
  }

  void _handleSSEEvent(SSEEvent event, String assistantMsgId) {
    final eventName = event.event;
    final data = event.data;

    switch (eventName) {
      case 'start':
        final convId = data['conversationId'] as String?;
        if (convId != null && convId.isNotEmpty) {
          state = state.copyWith(conversationId: convId);
        }
        break;

      case 'status':
        final stage = data['stage'] as String?;
        if (stage != null) {
          state = state.copyWith(streamingStage: stage);
        }
        break;

      case 'delta':
        final deltaText = data['text'] as String? ?? '';
        if (deltaText.isNotEmpty) {
          final updated = state.messages.map((m) {
            if (m.id == assistantMsgId) {
              return m.copyWith(content: m.content + deltaText);
            }
            return m;
          }).toList();
          state = state.copyWith(
            messages: updated,
            streamingStage: 'generating',
          );
        }
        break;

      case 'metrics':
        final metrics = FormaMetricsModel.fromJson(data);
        final updated = state.messages.map((m) {
          if (m.id == assistantMsgId) {
            return m.copyWith(metricsBlock: metrics);
          }
          return m;
        }).toList();
        state = state.copyWith(messages: updated);
        break;

      case 'proposal':
        final proposal = ActionProposalModel.fromJson(data);
        final updated = state.messages.map((m) {
          if (m.id == assistantMsgId) {
            final exists = m.proposals.any((p) => p.id == proposal.id);
            final updatedProposals = exists
                ? m.proposals.map((p) => p.id == proposal.id ? proposal : p).toList()
                : [...m.proposals, proposal];
            return m.copyWith(proposals: updatedProposals);
          }
          return m;
        }).toList();
        state = state.copyWith(messages: updated);
        break;

      case 'suggestions':
        final suggestionsModel = FormaSuggestionsModel.fromJson(data);
        final updated = state.messages.map((m) {
          if (m.id == assistantMsgId) {
            return m.copyWith(suggestionsBlock: suggestionsModel);
          }
          return m;
        }).toList();
        state = state.copyWith(
          messages: updated,
          currentSuggestions: suggestionsModel.chips,
        );
        break;

      case 'evidence':
        final evidenceModel = EvidenceClaimModel.fromJson(data);
        final updated = state.messages.map((m) {
          if (m.id == assistantMsgId) {
            return m.copyWith(evidenceClaims: [...m.evidenceClaims, evidenceModel]);
          }
          return m;
        }).toList();
        state = state.copyWith(messages: updated);
        break;

      case 'done':
        final finalContent = data['content'] as String?;
        final safetyCategory = data['safetyCategory'] as String?;
        final isEmergency = safetyCategory == 'D';

        final updated = state.messages.map((m) {
          if (m.id == assistantMsgId) {
            return m.copyWith(
              content: (finalContent != null && finalContent.isNotEmpty)
                  ? finalContent
                  : m.content,
              isEmergencyNotice: isEmergency,
            );
          }
          return m;
        }).toList();

        state = state.copyWith(
          messages: updated,
          isStreaming: false,
          clearStreamingStage: true,
        );
        break;

      case 'error':
        final code = data['code'] as String? ?? 'S02';
        state = state.copyWith(
          isStreaming: false,
          clearStreamingStage: true,
          activeErrorCode: code,
        );
        break;
    }
  }

  void _handleStreamError(dynamic err, String assistantMsgId) {
    String code = 'S02';
    final errStr = err.toString().toLowerCase();
    if (errStr.contains('socket') || errStr.contains('network') || errStr.contains('offline')) {
      code = 'S01';
    } else if (errStr.contains('timeout')) {
      code = 'S03';
    } else if (errStr.contains('rate') || errStr.contains('429')) {
      code = 'S05';
    }

    // Clean up empty assistant placeholder if failed right away
    final updated = state.messages.where((m) {
      if (m.id == assistantMsgId && m.content.isEmpty && m.proposals.isEmpty && m.metricsBlock == null) {
        return false;
      }
      return true;
    }).toList();

    state = state.copyWith(
      messages: updated,
      isStreaming: false,
      clearStreamingStage: true,
      activeErrorCode: code,
    );
  }

  Future<void> confirmProposal(String messageId, String proposalId) async {
    // 1. Optimistic transition: pending -> confirming
    final updatedConfirming = state.messages.map((msg) {
      if (msg.id == messageId) {
        final updatedProps = msg.proposals.map((p) {
          if (p.id == proposalId) {
            return p.copyWith(status: 'confirming');
          }
          return p;
        }).toList();
        return msg.copyWith(proposals: updatedProps);
      }
      return msg;
    }).toList();
    state = state.copyWith(messages: updatedConfirming);

    try {
      final result = await repository.confirmProposal(proposalId);

      // 2. Transition confirming -> executed with confirmed proposal from server
      final updatedExecuted = state.messages.map((msg) {
        if (msg.id == messageId) {
          final updatedProps = msg.proposals.map((p) {
            if (p.id == proposalId) {
              return result.proposal.copyWith(status: 'executed');
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

      state = state.copyWith(messages: [...updatedExecuted, receiptMsg]);
    } catch (err) {
      // 3. Transition confirming -> failed with error description
      final updatedFailed = state.messages.map((msg) {
        if (msg.id == messageId) {
          final updatedProps = msg.proposals.map((p) {
            if (p.id == proposalId) {
              return p.copyWith(
                status: 'failed',
                errorMessage: err.toString(),
              );
            }
            return p;
          }).toList();
          return msg.copyWith(proposals: updatedProps);
        }
        return msg;
      }).toList();

      state = state.copyWith(
        messages: updatedFailed,
        activeErrorCode: 'S07',
      );
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
            return p.copyWith(status: 'declined');
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
    stopStreaming();
    state = const AssistantChatState(
      messages: [],
      conversationId: null,
      currentSuggestions: [],
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
  final ScrollController _scrollController = ScrollController();
  bool _isNearBottom = true;
  bool _showJumpToLatest = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    // In reverse: true ListView, offset 0 is the bottom!
    final offset = _scrollController.offset;
    final isNear = offset < 80;
    if (isNear != _isNearBottom) {
      setState(() {
        _isNearBottom = isNear;
        _showJumpToLatest = !isNear;
      });
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final chatState = ref.watch(assistantChatProvider);

    // Auto-scroll on new tokens if user is already near bottom (<= 80dp)
    ref.listen(assistantChatProvider, (_, next) {
      if (_isNearBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients && _isNearBottom) {
            _scrollController.jumpTo(0.0);
          }
        });
      }
    });

    final messages = chatState.messages;
    final hasMessages = messages.isNotEmpty;

    // Display messages in reverse order for reverse: true ListView
    final reversedMessages = messages.reversed.toList();

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
        child: Stack(
          children: [
            Column(
              children: [
                // Chat List or Empty State
                Expanded(
                  child: !hasMessages
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: EmptyStateBento(
                            onPromptTap: (prompt) {
                              ref.read(assistantChatProvider.notifier).sendMessage(prompt, l10n);
                            },
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.only(top: 12, bottom: 8),
                          itemCount: reversedMessages.length,
                          itemBuilder: (context, index) {
                            final msg = reversedMessages[index];
                            final isUser = msg.role == 'user';

                            if (isUser) {
                              return UserBubble(message: msg);
                            }

                            return AssistantMessageView(
                              message: msg,
                              onConfirmProposal: (msgId, propId) {
                                ref.read(assistantChatProvider.notifier).confirmProposal(msgId, propId);
                              },
                              onDeclineProposal: (msgId, propId) {
                                ref.read(assistantChatProvider.notifier).declineProposal(msgId, propId);
                              },
                              onCopy: () {
                                Clipboard.setData(ClipboardData(text: msg.content));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.copiedToClipboard),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              onRetry: () {
                                ref.read(assistantChatProvider.notifier).retryLastPrompt(l10n);
                              },
                            );
                          },
                        ),
                ),

                // Typing indicator when streaming or retrieving context
                if (chatState.isStreaming && chatState.streamingStage != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TypingIndicator(stage: chatState.streamingStage!),
                  ),

                // Active error card if non-null
                if (chatState.activeErrorCode != null)
                  ChatErrorCard(
                    errorCode: chatState.activeErrorCode!,
                    onRetry: () {
                      ref.read(assistantChatProvider.notifier).retryLastPrompt(l10n);
                    },
                  ),

                // Composer with quick suggestions & streaming stop action
                Composer(
                  isStreaming: chatState.isStreaming,
                  suggestions: chatState.currentSuggestions,
                  onSuggestionTap: (chip) {
                    ref.read(assistantChatProvider.notifier).sendMessage(chip, l10n);
                  },
                  onSend: (text) {
                    ref.read(assistantChatProvider.notifier).sendMessage(text, l10n);
                  },
                  onStop: () {
                    ref.read(assistantChatProvider.notifier).stopStreaming();
                  },
                ),
              ],
            ),

            // Jump to latest button floating over list when scrolled back
            if (_showJumpToLatest)
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: JumpToLatestPill(
                  onTap: _scrollToBottom,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
