/**
 * Propose -> Confirm -> Commit Action Protocol (ADR-008, §12.5)
 *
 * Rules:
 * - AI cannot directly commit state changes; it emits Action Proposals only.
 * - Single-use token and expiration.
 * - User must confirm via UI action (cannot be confirmed via chat prompt injection).
 * - System persistence emits an Action Receipt.
 * - Success claims by AI are only valid when bound to an Action Receipt.
 */

import crypto from 'crypto';

export type ActionType =
  | 'save_measurement'
  | 'update_goal'
  | 'update_profile_attribute'
  | 'create_assistant_note';

export interface ActionProposal {
  id: string;
  userId: string;
  actionType: ActionType;
  description: { en: string; ar: string };
  diffPreview: Record<string, { before: unknown; after: unknown }>;
  payload: Record<string, unknown>;
  singleUseToken: string;
  expiresAt: string;
  status: 'pending' | 'confirmed' | 'rejected' | 'expired';
}

export interface ActionReceipt {
  receiptId: string;
  proposalId: string;
  userId: string;
  actionType: ActionType;
  committedRecordId: string;
  status: 'committed';
  committedAt: string;
}

export class ActionProtocolService {
  private static proposals: Map<string, ActionProposal> = new Map();
  private static receipts: Map<string, ActionReceipt> = new Map();

  /**
   * Model emits an Action Proposal.
   */
  static createProposal(params: {
    userId: string;
    actionType: ActionType;
    description: { en: string; ar: string };
    diffPreview: Record<string, { before: unknown; after: unknown }>;
    payload: Record<string, unknown>;
    ttlMinutes?: number;
  }): ActionProposal {
    const id = `prop_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const singleUseToken = crypto.randomBytes(24).toString('hex');
    const ttl = (params.ttlMinutes ?? 15) * 60 * 1000;
    const expiresAt = new Date(Date.now() + ttl).toISOString();

    const proposal: ActionProposal = {
      id,
      userId: params.userId,
      actionType: params.actionType,
      description: params.description,
      diffPreview: params.diffPreview,
      payload: params.payload,
      singleUseToken,
      expiresAt,
      status: 'pending',
    };

    this.proposals.set(id, proposal);
    return proposal;
  }

  /**
   * User confirms via out-of-band UI affordance.
   */
  static confirmProposal(
    proposalId: string,
    userId: string,
    token: string,
    commitExecutor: (payload: Record<string, unknown>) => string
  ): ActionReceipt {
    const proposal = this.proposals.get(proposalId);
    if (!proposal) {
      throw new Error(`Proposal '${proposalId}' not found`);
    }

    if (proposal.userId !== userId) {
      throw new Error('Unauthorized proposal confirmation attempt');
    }

    if (proposal.status !== 'pending') {
      throw new Error(`Proposal status is '${proposal.status}', cannot confirm`);
    }

    if (new Date() > new Date(proposal.expiresAt)) {
      proposal.status = 'expired';
      throw new Error('Proposal has expired');
    }

    if (proposal.singleUseToken !== token) {
      throw new Error('Invalid single-use confirmation token');
    }

    // Execute domain commit
    const committedRecordId = commitExecutor(proposal.payload);
    proposal.status = 'confirmed';

    const receipt: ActionReceipt = {
      receiptId: `rcpt_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      proposalId: proposal.id,
      userId,
      actionType: proposal.actionType,
      committedRecordId,
      status: 'committed',
      committedAt: new Date().toISOString(),
    };

    this.receipts.set(receipt.receiptId, receipt);
    return receipt;
  }

  static getReceipt(receiptId: string): ActionReceipt | undefined {
    return this.receipts.get(receiptId);
  }
}
