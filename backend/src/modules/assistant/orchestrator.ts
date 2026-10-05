import { withUserContext } from '../../core/database/index.js';
import { AIGateway } from '../ai/gateway/gateway.js';
import { BYOKService } from '../ai/gateway/byok.js';
import { AIContextEngine } from '../ai/context/engine.js';
import { AnalyticsService } from '../analytics/service.js';
import { MeasurementsService } from '../measurements/service.js';
import { GoalsService } from '../goals/service.js';
import { SafetyClassifier, SafetyCategory } from '../ai/safety/classifier.js';
import { AITraceService } from '../ai/traces/service.js';
import { ToolRegistry, ToolExecutor } from '../ai/tools/executor.js';
import { AssistantMemoryService } from './memory.js';
import { ActionProposalEngine } from './proposals.js';
import { EvidenceClaimVerifier } from './evidence.js';
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
  safetyCategory: string;
  createdAt: string;
}

export interface ChatStreamEvent {
  event: 'start' | 'delta' | 'evidence' | 'proposal' | 'done' | 'error';
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
   * Retrieves a specific conversation with all its messages and proposals.
   */
  async getConversation(
    userId: string,
    conversationId: string
  ): Promise<{ conversation: Conversation; messages: ConversationMessage[]; proposals: ActionProposal[] } | null> {
    return await withUserContext(userId, async (client) => {
      const convRes = await client.query(
        `SELECT * FROM conversations WHERE id = $1 AND user_id = $2`,
        [conversationId, userId]
      );
      if (convRes.rows.length === 0) return null;

      const msgRes = await client.query(
        `SELECT * FROM conversation_messages WHERE conversation_id = $1 AND user_id = $2 ORDER BY created_at ASC`,
        [conversationId, userId]
      );

      const propRes = await client.query(
        `SELECT * FROM action_proposals WHERE conversation_id = $1 AND user_id = $2 ORDER BY created_at ASC`,
        [conversationId, userId]
      );

      return {
        conversation: mapConversationRow(convRes.rows[0]),
        messages: msgRes.rows.map(mapMessageRow),
        proposals: propRes.rows.map(mapProposalRow)
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
    const userPrompt = req.message.trim();

    // 1. Safety classification
    const safety = SafetyClassifier.classify(userPrompt);

    // 2. Get or create conversation
    const conversation = await this.getOrCreateConversation(userId, req.conversationId, userPrompt);

    // 3. Persist user message
    const userMessage = await this.saveMessage(userId, {
      conversationId: conversation.id,
      role: 'user',
      content: userPrompt,
      evidenceClaims: [],
      proposals: [],
      tokenCount: Math.ceil(userPrompt.length / 4),
      safetyCategory: safety.category
    });

    // 4. If Safety Category D (Crisis/Acute Symptom), return immediate redirect
    if (safety.category === 'D') {
      const redirectText = safety.redirectMessage ||
        'Your safety and health are paramount. The symptoms or behaviors you described require immediate evaluation by a licensed healthcare professional or emergency medical services. Forma is an informational companion and does not provide medical treatment or diagnose conditions.';

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
        outcome: 'refusal'
      });

      return {
        conversationId: conversation.id,
        userMessageId: userMessage.id,
        assistantMessageId: assistantMsg.id,
        content: redirectText,
        evidenceClaims: [],
        proposals: [],
        safetyCategory: 'D',
        createdAt: assistantMsg.createdAt
      };
    }

    // 5. Build AI Context & Grounding
    const contextBundle = await this.contextEngine.assembleContext(userId, userPrompt);
    const durableMemories = await AssistantMemoryService.formatMemoriesForContext(userId);

    // 6. Fetch conversation history
    const history = await this.getRecentMessages(userId, conversation.id, 8);

    // 7. Check for uncommitted proposals or recent receipts in this conversation
    const recentProposals = await this.getRecentProposals(userId, conversation.id);
    const proposalsContextText = formatProposalsContext(recentProposals);

    // 8. Assemble system instructions with strict Propose -> Confirm -> Commit rules
    const systemInstruction = `
You are Forma, an intelligent, empathetic, evidence-based personal fitness and wellness companion.
You adhere strictly to safety, accuracy, and user privacy boundaries.

CRITICAL INVARIANTS:
1. CONTROLLED ACTIONS PROTOCOL (Propose -> Confirm -> Commit):
   - You CANNOT write to or modify the database directly.
   - If the user asks or intends to log a measurement (e.g. weight), update a goal, or save a memory/preference, you MUST propose the action by emitting a strictly formatted XML block:
     <action_proposal>
     {
       "actionType": "log_measurement" | "update_goal" | "save_memory",
       "parameters": { ... },
       "diffPreview": { "before": ..., "after": ..., "description": "..." },
       "humanReadableSummary": "Clear sentence describing what will be done upon confirmation"
     }
     </action_proposal>
   - Examples of parameters:
     - For log_measurement: { "typeCode": "weight", "value": 74.5, "unit": "kg", "observedAt": "${new Date().toISOString()}" }
     - For update_goal: { "targetMetricTypeCode": "weight", "targetValue": 70, "targetDate": "2026-12-31" }
     - For save_memory: { "category": "preference", "key": "dietary_preference", "value": "vegetarian" }
2. ACTION CLAIMS BOUND TO RECEIPTS:
   - You MUST NOT assert that an action succeeded, was saved, or was committed UNLESS you see an explicit Action Receipt with status 'executed' in the conversation context.
   - If an action was only proposed, inform the user that you've prepared the proposal and they can confirm it.
3. ANTI-HALLUCINATION & EVIDENCE LABELING:
   - Ground all numeric health claims strictly in the provided snapshot or tool data.
   - Tag substantive claims inline where appropriate:
     [Retrieved] for direct observations (e.g., recorded weight).
     [Calculated] for derived formulas (e.g., BMI, BMR, TDEE).
     [Estimated] for heuristic estimations.
     [Inferred] for trends.
     [Recommended] for caloric/macro targets and guidance.
   - If user data is missing, admit it transparently and ask the user to provide it.
4. BILINGUAL SUPPORT:
   - If the user speaks Arabic, reply naturally in Arabic while maintaining all proposal formats.
   - If English, reply in English.

USER MEMORIES & PREFERENCES:
${durableMemories}

HEALTH SNAPSHOT & CONTEXT:
${contextBundle.systemContextText}

${proposalsContextText}
`;

    // 9. Format message history into prompt
    let formattedPrompt = '';
    for (const msg of history) {
      if (msg.role === 'user') {
        formattedPrompt += `User: ${msg.content}\n`;
      } else if (msg.role === 'assistant') {
        formattedPrompt += `Forma: ${msg.content}\n`;
      }
    }
    formattedPrompt += `User: ${userPrompt}\nForma:`;

    // 10. Execute generation through AI Gateway
    let gatewayResult;
    try {
      gatewayResult = await this.gateway.execute(
        'conversational',
        {
          prompt: formattedPrompt,
          systemInstruction,
          temperature: 0.3,
          maxTokens: 1024
        },
        userId
      );
    } catch (providerError: any) {
      // Graceful degradation when AI provider is unavailable, timing out, or returning 5xx (Blueprint Gate 11)
      const isArabic = /[\u0600-\u06FF]/.test(userPrompt);
      const fallbackText = isArabic
        ? 'أواجه حالياً صعوبة مؤقتة في الاتصال بخدمة الذكاء الاصطناعي. بياناتك الصحية وسجلاتك محفوظة بأمان تام. يرجى إعادة المحاولة بعد لحظات، أو استخدام لوحة التحكم لتسجيل قياساتك مباشرة.'
        : 'I am currently experiencing temporary connectivity issues contacting the AI service. Your health metrics and records are completely safe. Please try again in a few moments, or record measurements directly via the dashboard.';

      const assistantMessage = await this.saveMessage(userId, {
        conversationId: conversation.id,
        role: 'assistant',
        content: fallbackText,
        evidenceClaims: [],
        proposals: [],
        tokenCount: Math.ceil(fallbackText.length / 4),
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
          excludedReasons: { provider_error: providerError.message || 'Provider degraded' },
          recordCount: 0,
          dataFreshness: 'none'
        },
        safetyCategory: 'A',
        guardrailsTriggered: [],
        outcome: 'degraded'
      });

      return {
        conversationId: conversation.id,
        userMessageId: userMessage.id,
        assistantMessageId: assistantMessage.id,
        content: fallbackText,
        evidenceClaims: [],
        proposals: [],
        safetyCategory: 'A',
        createdAt: assistantMessage.createdAt
      };
    }

    let rawText = gatewayResult.result.text;

    // 11. Extract and process any <action_proposal> blocks
    const extractedProposals: ActionProposal[] = [];
    const proposalRegex = /<action_proposal>([\s\S]*?)<\/action_proposal>/gi;
    let propMatch: RegExpExecArray | null;

    while ((propMatch = proposalRegex.exec(rawText)) !== null) {
      try {
        const jsonStr = (propMatch[1] ?? '').trim();
        const parsed = JSON.parse(jsonStr);
        if (parsed.actionType && parsed.parameters && parsed.humanReadableSummary) {
          const createdProp = await ActionProposalEngine.createProposal(userId, {
            conversationId: conversation.id,
            actionType: parsed.actionType,
            parameters: parsed.parameters,
            diffPreview: parsed.diffPreview || { after: parsed.parameters, description: parsed.humanReadableSummary },
            humanReadableSummary: parsed.humanReadableSummary
          });
          extractedProposals.push(createdProp);
        }
      } catch (err) {
        // Ignore unparseable proposal block
      }
    }

    // Clean text by replacing XML block with clean summary card marker
    let cleanText = rawText.replace(proposalRegex, (_match, p1) => {
      try {
        const parsed = JSON.parse((p1 ?? '').trim());
        return `\n\n📋 **Action Proposed:** ${parsed.humanReadableSummary}\n*(Please confirm or decline below)*\n`;
      } catch {
        return '';
      }
    }).trim();

    // 12. Extract and verify evidence claims against snapshot and tool data
    const evidenceClaims = EvidenceClaimVerifier.extractAndVerifyClaims(cleanText, {
      snapshot: contextBundle.snapshot
    });

    // 13. Save assistant message
    const assistantMessage = await this.saveMessage(userId, {
      conversationId: conversation.id,
      role: 'assistant',
      content: cleanText,
      evidenceClaims,
      proposals: extractedProposals,
      tokenCount: gatewayResult.result.usage.completionTokens || Math.ceil(cleanText.length / 4),
      safetyCategory: safety.category
    });

    // 14. Update proposal message_ids
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

    // 15. Record AI Trace
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
      outcome: 'success'
    });

    return {
      conversationId: conversation.id,
      userMessageId: userMessage.id,
      assistantMessageId: assistantMessage.id,
      content: cleanText,
      evidenceClaims,
      proposals: extractedProposals,
      safetyCategory: safety.category,
      createdAt: assistantMessage.createdAt
    };
  }

  /**
   * Handles a conversational turn with Server-Sent Events (SSE) streaming.
   */
  async *chatStream(
    userId: string,
    req: ChatRequest,
    correlationId: string
  ): AsyncGenerator<ChatStreamEvent> {
    const userPrompt = req.message.trim();
    const safety = SafetyClassifier.classify(userPrompt);
    const conversation = await this.getOrCreateConversation(userId, req.conversationId, userPrompt);

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
      const redirectText = safety.redirectMessage ||
        'Your safety and health are paramount. The symptoms or behaviors you described require immediate evaluation by a licensed healthcare professional or emergency medical services.';

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
          safetyCategory: 'D'
        }
      };
      return;
    }

    // Execute through full pipeline
    const chatResult = await this.chat(userId, req, correlationId);

    // Stream text in small chunks for smooth SSE client rendering
    const chunks = chatResult.content.match(/[\s\S]{1,24}/g) || [chatResult.content];
    for (const chunk of chunks) {
      yield { event: 'delta', data: { text: chunk } };
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
        safetyCategory: chatResult.safetyCategory
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

      const title = initialPrompt
        ? initialPrompt.length > 40
          ? initialPrompt.substring(0, 37) + '...'
          : initialPrompt
        : 'New Conversation';

      const insertRes = await client.query(
        `INSERT INTO conversations (user_id, title) VALUES ($1, $2) RETURNING *`,
        [userId, title]
      );
      return mapConversationRow(insertRes.rows[0]);
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

  private async getRecentMessages(
    userId: string,
    conversationId: string,
    limit = 10
  ): Promise<ConversationMessage[]> {
    return await withUserContext(userId, async (client) => {
      const res = await client.query(
        `SELECT * FROM conversation_messages
         WHERE conversation_id = $1 AND user_id = $2
         ORDER BY created_at ASC
         LIMIT $3`,
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
