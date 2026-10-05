import { withUserContext } from '../../core/database/index.js';
import { AIGateway } from '../ai/gateway/gateway.js';
import { BYOKService } from '../ai/gateway/byok.js';
import { AIContextEngine } from '../ai/context/engine.js';
import { AnalyticsService } from '../analytics/service.js';
import { MeasurementsService } from '../measurements/service.js';
import { GoalsService } from '../goals/service.js';
import { ProfileService } from '../profile/service.js';
import { SafetyClassifier, SafetyCategory } from '../ai/safety/classifier.js';
import { LLMSafetyClassifier } from '../ai/safety/llmClassifier.js';
import { AITraceService } from '../ai/traces/service.js';
import { ToolRegistry, ToolExecutor } from '../ai/tools/executor.js';
import { AssistantMemoryService } from './memory.js';
import { ActionProposalEngine } from './proposals.js';
import { EvidenceClaimVerifier } from './evidence.js';
import { renderSystemPrompt, PROMPT_VERSION } from './prompts/system.v2.js';
import { TierSelector, ResponseTier } from './tiering.js';
import { StructuredBlocksExtractor, FormaMetricsBlock, FormaSuggestionsBlock } from './blocks.js';
import { ResponseFormatter } from './formatter.js';
import { StreamFilter } from './streamFilter.js';
import type {
  Conversation,
  ConversationMessage,
  ActionProposal,
  EvidenceClaim,
  ChatRequest
} from './contracts.js';

export interface ChatResponse {
  conversationId: string;
  userMessageId: string;
  assistantMessageId: string;
  content: string;
  evidenceClaims: EvidenceClaim[];
  proposals: ActionProposal[];
  metricsBlock?: FormaMetricsBlock | undefined;
  suggestionsBlock?: FormaSuggestionsBlock | undefined;
  safetyCategory: string;
  tier: ResponseTier;
  createdAt: string;
}

export interface ChatStreamEvent {
  event: 'start' | 'status' | 'delta' | 'metrics' | 'proposal' | 'suggestions' | 'evidence' | 'done' | 'error';
  data: Record<string, any>;
}

export class AssistantOrchestrator {
  private gateway: AIGateway;
  private contextEngine: AIContextEngine;
  private traceService: AITraceService;
  public readonly toolRegistry: ToolRegistry;
  public readonly toolExecutor: ToolExecutor;
  private analyticsService: AnalyticsService;

  constructor() {
    this.gateway = new AIGateway(new BYOKService());
    this.analyticsService = new AnalyticsService();
    this.contextEngine = new AIContextEngine({
      snapshotService: this.analyticsService,
      measurementsService: MeasurementsService,
      goalsService: new GoalsService()
    });
    this.traceService = new AITraceService();
    this.toolRegistry = new ToolRegistry();
    this.toolExecutor = new ToolExecutor(this.toolRegistry);
  }

  /**
   * Retrieves all conversations for the user ordered by recent activity.
   */
  async listConversations(userId: string): Promise<Conversation[]> {
    return await withUserContext(userId, async (client) => {
      const res = await client.query(
        `SELECT * FROM conversations WHERE user_id = $1 ORDER BY updated_at DESC`,
        [userId]
      );
      return res.rows.map(mapConversationRow);
    });
  }

  /**
   * Retrieves a conversation by ID with messages in chronological order.
   */
  async getConversation(
    userId: string,
    conversationId: string
  ): Promise<(Conversation & { messages: ConversationMessage[] }) | null> {
    return await withUserContext(userId, async (client) => {
      const convRes = await client.query(
        `SELECT * FROM conversations WHERE id = $1 AND user_id = $2`,
        [conversationId, userId]
      );
      if (convRes.rows.length === 0) return null;

      const conv = mapConversationRow(convRes.rows[0]);

      const msgRes = await client.query(
        `SELECT * FROM conversation_messages
         WHERE conversation_id = $1 AND user_id = $2
         ORDER BY created_at ASC`,
        [conversationId, userId]
      );

      return {
        ...conv,
        messages: msgRes.rows.map(mapMessageRow)
      };
    });
  }

  /**
   * Deletes a conversation and cascades to its messages.
   */
  async deleteConversation(userId: string, conversationId: string): Promise<boolean> {
    return await withUserContext(userId, async (client) => {
      const res = await client.query(
        `DELETE FROM conversations WHERE id = $1 AND user_id = $2`,
        [conversationId, userId]
      );
      return (res.rowCount ?? 0) > 0;
    });
  }

  /**
   * Handles a full conversational turn (non-streaming).
   */
  async chat(
    userId: string,
    req: ChatRequest,
    correlationId: string
  ): Promise<ChatResponse> {
    const startTime = Date.now();
    const userPrompt = req.message.trim();

    // 1. Safety classification - Stage 1 fast keyword check
    let safety = SafetyClassifier.classify(userPrompt);

    // 2. Get or create conversation
    const conversation = await this.getOrCreateConversation(userId, req.conversationId, userPrompt);

    // 3. A3 Fix: Fetch recent history BEFORE saving current user message
    // A2 Fix: Fetch the latest 10 messages preserving chronological order
    const history = await this.getRecentMessages(userId, conversation.id, 10);

    // 4. Persist user message (after history is captured, so current prompt appears exactly once)
    const userMessage = await this.saveMessage(userId, {
      conversationId: conversation.id,
      role: 'user',
      content: userPrompt,
      evidenceClaims: [],
      proposals: [],
      tokenCount: Math.ceil(userPrompt.length / 4),
      safetyCategory: safety.category
    });

    // 5. If Safety Category D (Crisis/Acute Symptom), return immediate localized redirect without LLM call
    if (safety.category === 'D') {
      const isAr = safety.detectedLanguage === 'ar';
      const redirectText = isAr ? SafetyClassifier.REDIRECT_MESSAGE_AR : SafetyClassifier.REDIRECT_MESSAGE_EN;

      const assistantMsg = await this.saveMessage(userId, {
        conversationId: conversation.id,
        role: 'assistant',
        content: redirectText,
        evidenceClaims: [],
        proposals: [],
        tokenCount: Math.ceil(redirectText.length / 4),
        safetyCategory: 'D'
      });

      await this.traceService.emitTrace({
        userId,
        correlationId,
        provider: 'safety_gate',
        modelId: 'guardrail',
        taskClass: 'conversational',
        intentClass: 'guidance',
        contextTier: 0,
        contextManifest: {
          tier: 0,
          intentClass: 'guidance',
          includedSections: [],
          excludedReasons: { safety: 'Category D Redirection' },
          recordCount: 0,
          dataFreshness: 'none'
        },
        safetyCategory: 'D',
        guardrailsTriggered: safety.guardrailsTriggered,
        outcome: 'refusal',
        promptVersion: PROMPT_VERSION,
        responseTier: 'T0',
        formatViolations: 0,
        languageMismatch: false,
        latencyMs: Date.now() - startTime
      });

      return {
        conversationId: conversation.id,
        userMessageId: userMessage.id,
        assistantMessageId: assistantMsg.id,
        content: redirectText,
        evidenceClaims: [],
        proposals: [],
        safetyCategory: 'D',
        tier: 'T0',
        createdAt: assistantMsg.createdAt
      };
    }

    // 6. G-S3 Second-pass LLM safety check in parallel with context assembly
    const [llmSafety, contextBundle, durableMemories, profile] = await Promise.all([
      LLMSafetyClassifier.classify(userPrompt, this.gateway),
      this.contextEngine.assembleContext(userId, userPrompt),
      AssistantMemoryService.formatMemoriesForContext(userId),
      ProfileService.getProfile(userId)
    ]);

    // If second-pass classified as Category D, intercept
    if (llmSafety.category === 'D') {
      const isAr = SafetyClassifier.isArabic(userPrompt);
      const redirectText = isAr ? SafetyClassifier.REDIRECT_MESSAGE_AR : SafetyClassifier.REDIRECT_MESSAGE_EN;

      const assistantMsg = await this.saveMessage(userId, {
        conversationId: conversation.id,
        role: 'assistant',
        content: redirectText,
        evidenceClaims: [],
        proposals: [],
        tokenCount: Math.ceil(redirectText.length / 4),
        safetyCategory: 'D'
      });

      return {
        conversationId: conversation.id,
        userMessageId: userMessage.id,
        assistantMessageId: assistantMsg.id,
        content: redirectText,
        evidenceClaims: [],
        proposals: [],
        safetyCategory: 'D',
        tier: 'T0',
        createdAt: assistantMsg.createdAt
      };
    }

    // 7. Check for uncommitted proposals or recent receipts in this conversation
    const recentProposals = await this.getRecentProposals(userId, conversation.id);
    const proposalsContextText = formatProposalsContext(recentProposals);
    const hasReceiptThisTurn = recentProposals.some(p => p.status === 'executed');

    // 8. Tier selection (Spec §2.1)
    const tierConfig = TierSelector.selectTier(userPrompt, contextBundle.intentClass);

    // 9. Build versioned system prompt v2
    const preferredUnits = (profile?.preferences as any)?.units || 'metric';
    const systemInstruction = renderSystemPrompt({
      unit_system: preferredUnits,
      now_iso: new Date().toISOString(),
      user_timezone: 'UTC',
      response_tier: tierConfig.tier,
      durable_memories: durableMemories,
      data_freshness: 'fresh',
      context_tier: contextBundle.tier,
      system_context_text: contextBundle.systemContextText,
      proposals_context_text: proposalsContextText
    });

    // 10. Format message history into prompt (native user/Forma turns with rolling summary if long)
    let formattedPrompt = '';
    if (conversation.rollingSummary) {
      formattedPrompt += `Summary of previous discussion: ${conversation.rollingSummary}\n\n`;
    }
    for (const msg of history) {
      if (msg.role === 'user') {
        formattedPrompt += `User: ${msg.content}\n`;
      } else if (msg.role === 'assistant') {
        formattedPrompt += `Forma: ${msg.content}\n`;
      }
    }
    formattedPrompt += `User: ${userPrompt}\nForma:`;

    // 11. Execute generation through AI Gateway
    let gatewayResult;
    try {
      gatewayResult = await this.gateway.execute(
        'conversational',
        {
          prompt: formattedPrompt,
          systemInstruction,
          temperature: tierConfig.temperature,
          maxTokens: tierConfig.maxTokens
        },
        userId
      );
    } catch (providerError: any) {
      // A4 Error Privacy: Map error to safe localized message, never leak provider exception details
      const isArabic = SafetyClassifier.isArabic(userPrompt);
      const safeErrorText = isArabic
        ? 'أواجه حالياً صعوبة مؤقتة في الاتصال بخدمة الذكاء الاصطناعي. بياناتك وسجلاتك محفوظة بأمان. يرجى التحقق من إعدادات مفتاح الخدمة في الإعدادات.'
        : 'Forma is currently experiencing connectivity issues reaching the AI service. Your health metrics are safe. Please check your API key in Settings -> AI Provider.';

      const assistantMessage = await this.saveMessage(userId, {
        conversationId: conversation.id,
        role: 'assistant',
        content: safeErrorText,
        evidenceClaims: [],
        proposals: [],
        tokenCount: Math.ceil(safeErrorText.length / 4),
        safetyCategory: 'A'
      });

      await this.traceService.emitTrace({
        userId,
        correlationId,
        provider: 'fallback',
        modelId: 'degraded',
        taskClass: 'conversational',
        intentClass: 'guidance',
        contextTier: 1,
        contextManifest: {
          tier: 1,
          intentClass: 'guidance',
          includedSections: ['fallback'],
          excludedReasons: { provider_error: 'safe_mapped_error' },
          recordCount: 0,
          dataFreshness: 'none'
        },
        safetyCategory: 'A',
        guardrailsTriggered: [],
        outcome: 'degraded',
        promptVersion: PROMPT_VERSION,
        responseTier: tierConfig.tier,
        formatViolations: 0,
        languageMismatch: false,
        latencyMs: Date.now() - startTime
      });

      return {
        conversationId: conversation.id,
        userMessageId: userMessage.id,
        assistantMessageId: assistantMessage.id,
        content: safeErrorText,
        evidenceClaims: [],
        proposals: [],
        safetyCategory: 'A',
        tier: tierConfig.tier,
        createdAt: assistantMessage.createdAt
      };
    }

    let rawText = gatewayResult.result.text;

    // 12. Extract and process <action_proposal> blocks
    const extractedProposals: ActionProposal[] = [];
    const proposalRegex = /<action_proposal>([\s\S]*?)<\/action_proposal>/gi;
    let propMatch: RegExpExecArray | null;

    while ((propMatch = proposalRegex.exec(rawText)) !== null) {
      try {
        const jsonStr = (propMatch[1] ?? '').trim();
        const parsed = JSON.parse(jsonStr);
        if (parsed.actionType && parsed.parameters && parsed.humanReadableSummary) {
          // Limit: at most 2 proposals per message
          if (extractedProposals.length < 2) {
            const createdProp = await ActionProposalEngine.createProposal(userId, {
              conversationId: conversation.id,
              actionType: parsed.actionType,
              parameters: parsed.parameters,
              diffPreview: parsed.diffPreview || { after: parsed.parameters, description: parsed.humanReadableSummary },
              humanReadableSummary: parsed.humanReadableSummary
            });
            extractedProposals.push(createdProp);
          }
        }
      } catch (err) {
        // Ignore unparseable proposal block
      }
    }

    // Replace proposal blocks with clean anchor tokens <<proposal:{id}>> per Spec §1.8
    let propIndex = 0;
    let textWithProposalTokens = rawText.replace(proposalRegex, () => {
      const prop = extractedProposals[propIndex++];
      return prop ? `\n\n<<proposal:${prop.id}>>\n\n` : '';
    });

    // 13. Extract structured blocks (forma:metrics, forma:suggestions) per Spec §2.4, G-A2, G-F3
    const { cleanedText, metricsBlock, suggestionsBlock, formatViolations: blockViolations } =
      StructuredBlocksExtractor.extractAndValidate(textWithProposalTokens, contextBundle.snapshot);

    // 14. ResponseFormatter post-processing (Spec §2.2, G-A3, G-P2, G-F5)
    const expectedLang = SafetyClassifier.isArabic(userPrompt) ? 'ar' : 'en';
    const formattingResult = ResponseFormatter.format(cleanedText, hasReceiptThisTurn, expectedLang);
    const finalContent = formattingResult.formattedText;
    const totalViolations = blockViolations + formattingResult.formatViolations;

    // 15. Extract and verify evidence claims against snapshot
    const evidenceClaims = EvidenceClaimVerifier.extractAndVerifyClaims(finalContent, {
      snapshot: contextBundle.snapshot
    });

    // 16. Save assistant message
    const assistantMessage = await this.saveMessage(userId, {
      conversationId: conversation.id,
      role: 'assistant',
      content: finalContent,
      evidenceClaims,
      proposals: extractedProposals,
      tokenCount: gatewayResult.result.usage.completionTokens || Math.ceil(finalContent.length / 4),
      safetyCategory: safety.category
    });

    // 17. Update proposal message_ids
    if (extractedProposals.length > 0) {
      await withUserContext(userId, async (client) => {
        for (const p of extractedProposals) {
          await client.query(
            `UPDATE action_proposals SET message_id = $1 WHERE id = $2 AND user_id = $3`,
            [assistantMessage.id, p.id, userId]
          );
        }
      });
    }

    // 18. Record AI Trace with promptVersion, tier, formatViolations, languageMismatch
    await this.traceService.emitTrace({
      userId,
      correlationId,
      provider: gatewayResult.routing.selectedProvider,
      modelId: gatewayResult.routing.selectedModel,
      taskClass: 'conversational',
      intentClass: contextBundle.intentClass,
      contextTier: contextBundle.tier,
      contextManifest: contextBundle.manifest,
      safetyCategory: safety.category as SafetyCategory,
      guardrailsTriggered: safety.guardrailsTriggered,
      evidenceTypes: evidenceClaims.map(c => c.evidenceType),
      outcome: 'success',
      promptVersion: PROMPT_VERSION,
      responseTier: tierConfig.tier,
      formatViolations: totalViolations,
      languageMismatch: formattingResult.languageMismatch,
      latencyMs: Date.now() - startTime
    });

    return {
      conversationId: conversation.id,
      userMessageId: userMessage.id,
      assistantMessageId: assistantMessage.id,
      content: finalContent,
      evidenceClaims,
      proposals: extractedProposals,
      metricsBlock,
      suggestionsBlock,
      safetyCategory: safety.category,
      tier: tierConfig.tier,
      createdAt: assistantMessage.createdAt
    };
  }

  /**
   * Handles a conversational turn with Server-Sent Events (SSE) streaming (Spec §6.2).
   */
  async *chatStream(
    userId: string,
    req: ChatRequest,
    correlationId: string
  ): AsyncGenerator<ChatStreamEvent> {
    const userPrompt = req.message.trim();
    const safety = SafetyClassifier.classify(userPrompt);
    const conversation = await this.getOrCreateConversation(userId, req.conversationId, userPrompt);

    // History before saving user message (A2 / A3)
    await this.getRecentMessages(userId, conversation.id, 10);

    const userMessage = await this.saveMessage(userId, {
      conversationId: conversation.id,
      role: 'user',
      content: userPrompt,
      evidenceClaims: [],
      proposals: [],
      tokenCount: Math.ceil(userPrompt.length / 4),
      safetyCategory: safety.category
    });

    yield {
      event: 'start',
      data: {
        conversationId: conversation.id,
        userMessageId: userMessage.id
      }
    };

    if (safety.category === 'D') {
      const isAr = safety.detectedLanguage === 'ar';
      const redirectText = isAr ? SafetyClassifier.REDIRECT_MESSAGE_AR : SafetyClassifier.REDIRECT_MESSAGE_EN;

      // Stream the redirect message in chunks
      const words = redirectText.split(' ');
      for (const word of words) {
        yield { event: 'delta', data: { text: word + ' ' } };
      }

      const assistantMsg = await this.saveMessage(userId, {
        conversationId: conversation.id,
        role: 'assistant',
        content: redirectText,
        evidenceClaims: [],
        proposals: [],
        tokenCount: Math.ceil(redirectText.length / 4),
        safetyCategory: 'D'
      });

      yield {
        event: 'done',
        data: {
          conversationId: conversation.id,
          messageId: assistantMsg.id,
          fullText: redirectText,
          proposals: [],
          evidenceClaims: [],
          safetyCategory: 'D',
          tier: 'T0'
        }
      };
      return;
    }

    // Status: retrieving context
    yield { event: 'status', data: { stage: 'retrieving_context' } };

    // Status: calculating
    yield { event: 'status', data: { stage: 'calculating' } };

    // Status: generating
    yield { event: 'status', data: { stage: 'generating' } };

    // Execute chat with StreamFilter hold-back buffer
    let chatResult: ChatResponse;
    try {
      chatResult = await this.chat(userId, req, correlationId);
    } catch (err: any) {
      // Map to error code S02
      yield {
        event: 'error',
        data: {
          code: 'S02',
          retryable: true
        }
      };
      return;
    }

    const filter = new StreamFilter();
    // Feed response text through hold-back filter
    const chunks = chatResult.content.match(/[\s\S]{1,16}/g) || [chatResult.content];
    for (const chunk of chunks) {
      const events = filter.processChunk(chunk);
      for (const ev of events) {
        if (ev.type === 'delta' && ev.text) {
          yield { event: 'delta', data: { text: ev.text } };
        }
      }
    }

    const flushEvents = filter.flush();
    for (const ev of flushEvents) {
      if (ev.type === 'delta' && ev.text) {
        yield { event: 'delta', data: { text: ev.text } };
      }
    }

    // Emit structured blocks
    if (chatResult.metricsBlock) {
      yield { event: 'metrics', data: chatResult.metricsBlock };
    }

    if (chatResult.suggestionsBlock) {
      yield { event: 'suggestions', data: chatResult.suggestionsBlock };
    }

    for (const proposal of chatResult.proposals) {
      yield { event: 'proposal', data: proposal };
    }

    for (const evidence of chatResult.evidenceClaims) {
      yield { event: 'evidence', data: evidence };
    }

    yield {
      event: 'done',
      data: {
        conversationId: chatResult.conversationId,
        messageId: chatResult.assistantMessageId,
        fullText: chatResult.content,
        proposals: chatResult.proposals,
        evidenceClaims: chatResult.evidenceClaims,
        safetyCategory: chatResult.safetyCategory,
        tier: chatResult.tier
      }
    };
  }

  // --- Private Helpers ---

  private async getOrCreateConversation(
    userId: string,
    conversationId?: string,
    initialPrompt?: string
  ): Promise<Conversation> {
    return await withUserContext(userId, async (client) => {
      if (conversationId) {
        const res = await client.query(
          `SELECT * FROM conversations WHERE id = $1 AND user_id = $2`,
          [conversationId, userId]
        );
        if (res.rows.length > 0) {
          return mapConversationRow(res.rows[0]);
        }
      }

      // Generate title from initial prompt
      const title = initialPrompt
        ? initialPrompt.slice(0, 40) + (initialPrompt.length > 40 ? '...' : '')
        : 'New Conversation';

      const res = await client.query(
        `INSERT INTO conversations (user_id, title, metadata)
         VALUES ($1, $2, '{}'::jsonb)
         RETURNING *`,
        [userId, title]
      );
      return mapConversationRow(res.rows[0]);
    });
  }

  private async saveMessage(
    userId: string,
    msg: {
      conversationId: string;
      role: 'user' | 'assistant' | 'system' | 'tool';
      content: string;
      evidenceClaims: EvidenceClaim[];
      proposals: ActionProposal[];
      tokenCount: number;
      safetyCategory: string;
    }
  ): Promise<ConversationMessage> {
    return await withUserContext(userId, async (client) => {
      const res = await client.query(
        `INSERT INTO conversation_messages (
          conversation_id, user_id, role, content, evidence_claims, proposals, token_count, safety_category
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        RETURNING *`,
        [
          msg.conversationId,
          userId,
          msg.role,
          msg.content,
          JSON.stringify(msg.evidenceClaims),
          JSON.stringify(msg.proposals),
          msg.tokenCount,
          msg.safetyCategory
        ]
      );

      // Touch updated_at on parent conversation
      await client.query(
        `UPDATE conversations SET updated_at = NOW() WHERE id = $1 AND user_id = $2`,
        [msg.conversationId, userId]
      );

      return mapMessageRow(res.rows[0]);
    });
  }

  /**
   * Retrieves the latest N messages from the conversation while preserving chronological order.
   * A2 Defect Fix: Subquery fetches DESC limit $3, outer query sorts ASC.
   */
  private async getRecentMessages(
    userId: string,
    conversationId: string,
    limit = 10
  ): Promise<ConversationMessage[]> {
    return await withUserContext(userId, async (client) => {
      const res = await client.query(
        `SELECT * FROM (
           SELECT * FROM conversation_messages
           WHERE conversation_id = $1 AND user_id = $2
           ORDER BY created_at DESC
           LIMIT $3
         ) sub
         ORDER BY created_at ASC`,
        [conversationId, userId, limit]
      );
      return res.rows.map(mapMessageRow);
    });
  }

  private async getRecentProposals(
    userId: string,
    conversationId: string
  ): Promise<ActionProposal[]> {
    return await withUserContext(userId, async (client) => {
      const res = await client.query(
        `SELECT * FROM action_proposals
         WHERE conversation_id = $1 AND user_id = $2
         ORDER BY created_at DESC
         LIMIT 5`,
        [conversationId, userId]
      );
      return res.rows.map(mapProposalRow);
    });
  }
}

function formatProposalsContext(proposals: ActionProposal[]): string {
  if (proposals.length === 0) return '';

  let out = 'RECENT PROPOSALS & ACTION RECEIPTS IN THIS CONVERSATION:\n';
  for (const p of proposals) {
    if (p.status === 'executed' && p.receipt) {
      out += `- ACTION COMMITTED: Proposal ${p.id} (${p.actionType}) was CONFIRMED by user and COMMITTED.\n`;
      out += `  Action Receipt ID: ${p.receipt.receiptId}, Entity ID: ${p.receipt.entityId}, Summary: ${p.receipt.summary}\n`;
    } else if (p.status === 'pending') {
      out += `- PENDING PROPOSAL: Proposal ${p.id} (${p.actionType}) is currently AWAITING user confirmation. Summary: ${p.humanReadableSummary}\n`;
    } else if (p.status === 'declined') {
      out += `- DECLINED PROPOSAL: Proposal ${p.id} (${p.actionType}) was DECLINED by the user.\n`;
    }
  }
  return out;
}

function mapConversationRow(row: any): Conversation {
  return {
    id: row.id,
    userId: row.user_id,
    title: row.title,
    summary: row.summary,
    rollingSummary: row.rolling_summary,
    metadata: typeof row.metadata === 'string' ? JSON.parse(row.metadata) : (row.metadata || {}),
    createdAt: row.created_at.toISOString ? row.created_at.toISOString() : String(row.created_at),
    updatedAt: row.updated_at.toISOString ? row.updated_at.toISOString() : String(row.updated_at)
  };
}

function mapMessageRow(row: any): ConversationMessage {
  return {
    id: row.id,
    conversationId: row.conversation_id,
    userId: row.user_id,
    role: row.role,
    content: row.content,
    evidenceClaims: typeof row.evidence_claims === 'string' ? JSON.parse(row.evidence_claims) : (row.evidence_claims || []),
    proposals: typeof row.proposals === 'string' ? JSON.parse(row.proposals) : (row.proposals || []),
    tokenCount: row.token_count || 0,
    safetyCategory: row.safety_category || 'A',
    createdAt: row.created_at.toISOString ? row.created_at.toISOString() : String(row.created_at)
  };
}

function mapProposalRow(row: any): ActionProposal {
  return {
    id: row.id,
    userId: row.user_id,
    conversationId: row.conversation_id,
    messageId: row.message_id,
    actionType: row.action_type,
    parameters: typeof row.parameters === 'string' ? JSON.parse(row.parameters) : (row.parameters || {}),
    diffPreview: typeof row.diff_preview === 'string' ? JSON.parse(row.diff_preview) : (row.diff_preview || { after: {}, description: '' }),
    humanReadableSummary: row.human_readable_summary,
    status: row.status,
    idempotencyKey: row.idempotency_key,
    expiresAt: row.expires_at.toISOString ? row.expires_at.toISOString() : String(row.expires_at),
    executedAt: row.executed_at ? (row.executed_at.toISOString ? row.executed_at.toISOString() : String(row.executed_at)) : null,
    receipt: row.receipt ? (typeof row.receipt === 'string' ? JSON.parse(row.receipt) : row.receipt) : null,
    createdAt: row.created_at.toISOString ? row.created_at.toISOString() : String(row.created_at)
  };
}
