import crypto from 'crypto';
import { withUserContext } from '../../core/database/index.js';
import { MeasurementsService } from '../measurements/service.js';
import { GoalsService } from '../goals/service.js';
import { AssistantMemoryService } from './memory.js';
import { AuditService } from '../audit/index.js';
import type {
  ActionProposal,
  ActionReceipt,
  ActionType,
  ActionProposalDiffPreview
} from './contracts.js';

export interface CreateProposalInput {
  conversationId?: string | null;
  messageId?: string | null;
  actionType: ActionType;
  parameters: Record<string, any>;
  diffPreview: ActionProposalDiffPreview;
  humanReadableSummary: string;
  expiryMinutes?: number;
}

export class ActionProposalEngine {
  private static goalsService = new GoalsService();

  /**
   * Generates a new action proposal with explicit idempotency key and expiration.
   * Does NOT execute any write to domain state.
   */
  static async createProposal(
    userId: string,
    input: CreateProposalInput
  ): Promise<ActionProposal> {
    // G-A4: Implausible-value gate (Spec §4.2 G-A4)
    if (input.actionType === 'log_measurement') {
      const typeCode = input.parameters?.typeCode;
      const val = Number(input.parameters?.value);
      if (!isNaN(val)) {
        if (typeCode === 'weight' && (val < 20 || val > 350)) {
          throw new Error(`Implausible weight value: ${val}. Plausible physiological bounds are 20 to 350 kg.`);
        }
        if (typeCode === 'body_fat_percentage' && (val < 2 || val > 70)) {
          throw new Error(`Implausible body fat value: ${val}%. Plausible physiological bounds are 2% to 70%.`);
        }
        if (typeCode === 'height' && (val < 50 || val > 270)) {
          throw new Error(`Implausible height value: ${val} cm. Plausible bounds are 50 to 270 cm.`);
        }
      }
    }

    // G-A6: Prompt injection defense in save_memory (Spec §4.2 G-A6)
    if (input.actionType === 'save_memory') {
      const val = String(input.parameters?.value || '');
      const suspiciousPattern = /\b(ignore\s+all\s+previous|system\s+prompt|you\s+are\s+now|developer\s+mode|override\s+instructions)\b/i;
      if (suspiciousPattern.test(val)) {
        throw new Error('Instruction-like pattern detected in memory proposal. Cannot save as memory.');
      }
    }

    const idempotencyKey = `prop_${crypto.randomUUID()}`;
    const expiryMinutes = input.expiryMinutes ?? 15;
    const expiresAt = new Date(Date.now() + expiryMinutes * 60 * 1000).toISOString();

    return await withUserContext(userId, async (client) => {
      const query = `
        INSERT INTO action_proposals (
          user_id, conversation_id, message_id, action_type,
          parameters, diff_preview, human_readable_summary,
          status, idempotency_key, expires_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'pending', $8, $9)
        RETURNING *
      `;

      const result = await client.query(query, [
        userId,
        input.conversationId || null,
        input.messageId || null,
        input.actionType,
        JSON.stringify(input.parameters),
        JSON.stringify(input.diffPreview),
        input.humanReadableSummary,
        idempotencyKey,
        expiresAt
      ]);

      return mapProposalRow(result.rows[0]);
    });
  }

  /**
   * Retrieves a proposal by ID scoped to the authenticated user.
   */
  static async getProposal(userId: string, proposalId: string): Promise<ActionProposal | null> {
    return await withUserContext(userId, async (client) => {
      const result = await client.query(
        `SELECT * FROM action_proposals WHERE id = $1 AND user_id = $2`,
        [proposalId, userId]
      );
      if (result.rows.length === 0) return null;
      return mapProposalRow(result.rows[0]);
    });
  }

  /**
   * Confirms and executes an action proposal.
   * Strict adherence to Blueprint §32 Invariant:
   * Propose -> Confirm -> Commit.
   * Generates an immutable Action Receipt upon successful commit.
   */
  static async confirmProposal(
    userId: string,
    proposalId: string,
    correlationId: string,
    idempotencyKey?: string
  ): Promise<{ proposal: ActionProposal; receipt: ActionReceipt }> {
    const proposal = await this.getProposal(userId, proposalId);
    if (!proposal) {
      throw new Error(`Action proposal not found: ${proposalId}`);
    }

    // Verify idempotency key if supplied
    if (idempotencyKey && proposal.idempotencyKey !== idempotencyKey) {
      // If already executed with this key, return it
      if (proposal.status === 'executed' && proposal.receipt) {
        return { proposal, receipt: proposal.receipt };
      }
    }

    // Idempotent retry: if already executed with receipt, return existing receipt
    if (proposal.status === 'executed' && proposal.receipt) {
      return { proposal, receipt: proposal.receipt };
    }

    if (proposal.status !== 'pending') {
      throw new Error(`Proposal cannot be confirmed: status is '${proposal.status}'`);
    }

    const now = new Date();
    if (new Date(proposal.expiresAt) < now) {
      await withUserContext(userId, async (client) => {
        await client.query(
          `UPDATE action_proposals SET status = 'expired' WHERE id = $1 AND user_id = $2`,
          [proposalId, userId]
        );
      });
      throw new Error('Action proposal has expired and cannot be confirmed');
    }

    let receipt: ActionReceipt;

    switch (proposal.actionType) {
      case 'log_measurement': {
        const params = proposal.parameters;
        const observedAt = params.observedAt || new Date().toISOString();
        const obs = await MeasurementsService.recordObservation(
          userId,
          {
            typeCode: params.typeCode,
            value: Number(params.value),
            unit: params.unit,
            observedAt,
            // Null-safe: service derives the user's real timezone from history
            // when the proposal does not carry one — never fabricate 'UTC'.
            timeZone: params.timeZone,
            originType: 'manual_entry',
            epistemicClass: 'measured',
            actor: 'user',
            confidenceScore: 1.0,
            reviewState: 'user_reviewed'
          },
          correlationId
        );

        receipt = {
          receiptId: crypto.randomUUID(),
          proposalId: proposal.id,
          actionType: 'log_measurement',
          committedAt: new Date().toISOString(),
          entityId: obs.observation.id,
          entityType: 'observation',
          provenance: 'assistant_proposal',
          summary: `Successfully recorded ${params.value} ${params.unit} for ${params.typeCode}`
        };
        break;
      }

      case 'update_goal': {
        const params = proposal.parameters;
        let goalId = params.goalId;

        if (goalId) {
          const updated = await this.goalsService.addGoalVersion(userId, goalId, {
            targetValue: Number(params.targetValue),
            targetDate: params.targetDate
          });
          goalId = updated.id;
        } else {
          const created = await this.goalsService.createGoal(userId, {
            goalType: params.goalType || 'maintenance',
            targetMetricTypeCode: params.targetMetricTypeCode || 'weight',
            targetValue: Number(params.targetValue),
            startingValue: Number(params.startingValue || params.targetValue),
            startDate: params.startDate || new Date().toISOString().slice(0, 10),
            targetDate: params.targetDate,
            isPrimary: params.isPrimary !== undefined ? Boolean(params.isPrimary) : true,
            rationale: params.rationale
          });
          goalId = created.id;
        }

        receipt = {
          receiptId: crypto.randomUUID(),
          proposalId: proposal.id,
          actionType: 'update_goal',
          committedAt: new Date().toISOString(),
          entityId: goalId,
          entityType: 'goal',
          provenance: 'assistant_proposal',
          summary: `Successfully updated goal to ${params.targetValue}`
        };
        break;
      }

      case 'save_memory': {
        const params = proposal.parameters;
        const memory = await AssistantMemoryService.saveMemory(
          userId,
          {
            category: params.category,
            key: params.key,
            value: params.value,
            confidence: params.confidence ?? 1.0
          },
          proposal.id,
          'assistant_proposal'
        );

        receipt = {
          receiptId: crypto.randomUUID(),
          proposalId: proposal.id,
          actionType: 'save_memory',
          committedAt: new Date().toISOString(),
          entityId: memory.id,
          entityType: 'assistant_memory',
          provenance: 'assistant_proposal',
          summary: `Saved preference "${params.key}: ${params.value}"`
        };
        break;
      }

      default:
        throw new Error(`Unsupported proposal action type: ${proposal.actionType}`);
    }

    // Commit proposal state update with receipt
    const updatedProposal = await withUserContext(userId, async (client) => {
      const result = await client.query(
        `UPDATE action_proposals
         SET status = 'executed', executed_at = NOW(), receipt = $1
         WHERE id = $2 AND user_id = $3
         RETURNING *`,
        [JSON.stringify(receipt), proposalId, userId]
      );
      return mapProposalRow(result.rows[0]);
    });

    await AuditService.recordEvent({
      userId,
      actorType: 'user',
      action: 'action_proposal_confirmed_and_executed',
      entityType: receipt.entityType,
      entityId: receipt.entityId,
      correlationId,
      status: 'success',
      metadata: {
        proposalId,
        actionType: proposal.actionType,
        receiptId: receipt.receiptId
      }
    });

    return { proposal: updatedProposal, receipt };
  }

  /**
   * User explicitly declines a proposed action.
   */
  static async declineProposal(
    userId: string,
    proposalId: string,
    correlationId: string
  ): Promise<ActionProposal> {
    const proposal = await this.getProposal(userId, proposalId);
    if (!proposal) {
      throw new Error(`Action proposal not found: ${proposalId}`);
    }

    if (proposal.status !== 'pending') {
      throw new Error(`Cannot decline proposal with status '${proposal.status}'`);
    }

    const updated = await withUserContext(userId, async (client) => {
      const result = await client.query(
        `UPDATE action_proposals SET status = 'declined' WHERE id = $1 AND user_id = $2 RETURNING *`,
        [proposalId, userId]
      );
      return mapProposalRow(result.rows[0]);
    });

    await AuditService.recordEvent({
      userId,
      actorType: 'user',
      action: 'action_proposal_declined',
      entityType: 'action_proposal',
      entityId: proposalId,
      correlationId,
      status: 'success',
      metadata: { proposalId }
    });

    return updated;
  }
}

function mapProposalRow(row: any): ActionProposal {
  return {
    id: row.id,
    userId: row.user_id,
    conversationId: row.conversation_id,
    messageId: row.message_id,
    actionType: row.action_type,
    parameters: typeof row.parameters === 'string' ? JSON.parse(row.parameters) : row.parameters,
    diffPreview: typeof row.diff_preview === 'string' ? JSON.parse(row.diff_preview) : row.diff_preview,
    humanReadableSummary: row.human_readable_summary,
    status: row.status,
    idempotencyKey: row.idempotency_key,
    expiresAt: row.expires_at.toISOString ? row.expires_at.toISOString() : String(row.expires_at),
    executedAt: row.executed_at ? (row.executed_at.toISOString ? row.executed_at.toISOString() : String(row.executed_at)) : null,
    receipt: row.receipt ? (typeof row.receipt === 'string' ? JSON.parse(row.receipt) : row.receipt) : null,
    createdAt: row.created_at.toISOString ? row.created_at.toISOString() : String(row.created_at)
  };
}
