import { withUserContext, withPurgeContext } from '../../../core/database/index.js';
import { ContextManifest, IntentClass } from '../context/types.js';
import { TaskClass } from '../gateway/types.js';
import { BudgetConsumption } from '../budget/index.js';
import { ExportableModule, DeletableModule } from '../../privacy/index.js';

export interface CreateTraceInput {
  userId: string;
  correlationId: string;
  provider: string;
  modelId: string;
  taskClass: TaskClass;
  intentClass: IntentClass;
  contextTier: number;
  contextManifest: ContextManifest;
  toolsInvoked?: Array<{ tool: string; success: boolean; latencyMs: number }> | undefined;
  evidenceTypes?: string[] | undefined;
  safetyCategory?: 'A' | 'B' | 'C' | 'D' | undefined;
  guardrailsTriggered?: string[] | undefined;
  budgetConsumed?: BudgetConsumption | undefined;
  outcome?: 'success' | 'error' | 'refusal' | 'degraded' | undefined;
  promptVersion?: string | undefined;
  responseTier?: string | undefined;
  formatViolations?: number | undefined;
  languageMismatch?: boolean | undefined;
  latencyMs?: number | undefined;
}

export interface AITraceRecord extends CreateTraceInput {
  id: string;
  createdAt: Date;
}

export class AITraceService implements ExportableModule, DeletableModule {
  public readonly moduleName = 'ai_traces';
  constructor(_pool?: any) {}

  public async emitTrace(input: CreateTraceInput): Promise<AITraceRecord> {
    return withUserContext(input.userId, async (client) => {
      const res = await client.query(
        `INSERT INTO ai_traces (
          user_id, correlation_id, provider, model_id, task_class, intent_class,
          context_tier, context_manifest, tools_invoked, evidence_types,
          safety_category, guardrails_triggered, budget_consumed, outcome,
          prompt_version, response_tier, format_violations, language_mismatch, latency_ms
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19)
        RETURNING id, user_id, correlation_id, provider, model_id, task_class, intent_class,
                  context_tier, context_manifest, tools_invoked, evidence_types,
                  safety_category, guardrails_triggered, budget_consumed, outcome,
                  prompt_version, response_tier, format_violations, language_mismatch, latency_ms, created_at`,
        [
          input.userId,
          input.correlationId,
          input.provider,
          input.modelId,
          input.taskClass,
          input.intentClass,
          input.contextTier,
          JSON.stringify(input.contextManifest),
          JSON.stringify(input.toolsInvoked || []),
          JSON.stringify(input.evidenceTypes || []),
          input.safetyCategory || 'A',
          JSON.stringify(input.guardrailsTriggered || []),
          JSON.stringify(input.budgetConsumed || {}),
          input.outcome || 'success',
          input.promptVersion || '2.0.0',
          input.responseTier || 'T1',
          input.formatViolations ?? 0,
          input.languageMismatch ?? false,
          input.latencyMs ?? 0,
        ]
      );

      const row = res.rows[0];
      return {
        id: row.id,
        userId: row.user_id,
        correlationId: row.correlation_id,
        provider: row.provider,
        modelId: row.model_id,
        taskClass: row.task_class,
        intentClass: row.intent_class,
        contextTier: row.context_tier,
        contextManifest: row.context_manifest,
        toolsInvoked: row.tools_invoked,
        evidenceTypes: row.evidence_types,
        safetyCategory: row.safety_category,
        guardrailsTriggered: row.guardrails_triggered,
        budgetConsumed: row.budget_consumed,
        outcome: row.outcome,
        createdAt: row.created_at,
      };
    });
  }

  public async getUserTraces(userId: string, limit = 20): Promise<AITraceRecord[]> {
    return withUserContext(userId, async (client) => {
      const res = await client.query(
        `SELECT id, user_id, correlation_id, provider, model_id, task_class, intent_class,
                context_tier, context_manifest, tools_invoked, evidence_types,
                safety_category, guardrails_triggered, budget_consumed, outcome, created_at
         FROM ai_traces
         WHERE user_id = $1
         ORDER BY created_at DESC
         LIMIT $2`,
        [userId, limit]
      );

      return res.rows.map((row) => ({
        id: row.id,
        userId: row.user_id,
        correlationId: row.correlation_id,
        provider: row.provider,
        modelId: row.model_id,
        taskClass: row.task_class,
        intentClass: row.intent_class,
        contextTier: row.context_tier,
        contextManifest: row.context_manifest,
        toolsInvoked: row.tools_invoked,
        evidenceTypes: row.evidence_types,
        safetyCategory: row.safety_category,
        guardrailsTriggered: row.guardrails_triggered,
        budgetConsumed: row.budget_consumed,
        outcome: row.outcome,
        createdAt: row.created_at,
      }));
    });
  }

  public async exportData(userId: string): Promise<Record<string, unknown>> {
    return this.exportUserData(userId);
  }

  // PrivacyExportModule
  public async exportUserData(userId: string): Promise<Record<string, unknown>> {
    const traces = await this.getUserTraces(userId, 100);
    return {
      aiTracesCount: traces.length,
      traces: traces.map((t) => ({
        id: t.id,
        correlationId: t.correlationId,
        provider: t.provider,
        modelId: t.modelId,
        taskClass: t.taskClass,
        intentClass: t.intentClass,
        contextTier: t.contextTier,
        contextManifest: t.contextManifest,
        safetyCategory: t.safetyCategory,
        createdAt: t.createdAt,
      })),
    };
  }

  // PrivacyPurgeModule
  public async purgeUserData(userId: string): Promise<void> {
    await withPurgeContext(userId, async (client) => {
      await client.query('DELETE FROM ai_traces WHERE user_id = $1', [userId]);
      await client.query('DELETE FROM user_ai_credentials WHERE user_id = $1', [userId]);
    });
  }

  public async purgeData(userId: string): Promise<void> {
    return this.purgeUserData(userId);
  }
}
