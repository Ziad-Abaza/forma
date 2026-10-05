import { withPurgeContext, withUserContext } from '../../core/database/index.js';
import type { ModulePrivacyContract, ExportPayload, DeletionResult } from '../privacy/index.js';

export * from './contracts.js';
export * from './memory.js';
export * from './proposals.js';
export * from './evidence.js';
export * from './orchestrator.js';

export class AssistantPrivacyContract implements ModulePrivacyContract {
  public readonly moduleName = 'assistant';

  async exportData(userId: string): Promise<ExportPayload> {
    const data = await withUserContext(userId, async (client) => {
      const convs = await client.query(
        `SELECT id, title, summary, rolling_summary, created_at, updated_at FROM conversations WHERE user_id = $1`,
        [userId]
      );
      const msgs = await client.query(
        `SELECT id, conversation_id, role, content, evidence_claims, proposals, token_count, safety_category, created_at FROM conversation_messages WHERE user_id = $1`,
        [userId]
      );
      const props = await client.query(
        `SELECT id, conversation_id, action_type, parameters, diff_preview, human_readable_summary, status, idempotency_key, expires_at, executed_at, receipt, created_at FROM action_proposals WHERE user_id = $1`,
        [userId]
      );
      const mems = await client.query(
        `SELECT id, category, key, value, confidence, source, is_active, created_at, updated_at FROM assistant_memories WHERE user_id = $1`,
        [userId]
      );

      return {
        conversations: convs.rows,
        messages: msgs.rows,
        actionProposals: props.rows,
        memories: mems.rows
      };
    });

    return {
      module: this.moduleName,
      version: '1.0.0',
      exportedAt: new Date().toISOString(),
      data
    };
  }

  async purgeUserData(userId: string): Promise<DeletionResult> {
    let totalDeleted = 0;

    await withPurgeContext(userId, async (client) => {
      const memRes = await client.query(`DELETE FROM assistant_memories WHERE user_id = $1`, [userId]);
      const propRes = await client.query(`DELETE FROM action_proposals WHERE user_id = $1`, [userId]);
      const msgRes = await client.query(`DELETE FROM conversation_messages WHERE user_id = $1`, [userId]);
      const convRes = await client.query(`DELETE FROM conversations WHERE user_id = $1`, [userId]);

      totalDeleted =
        (memRes.rowCount ?? 0) +
        (propRes.rowCount ?? 0) +
        (msgRes.rowCount ?? 0) +
        (convRes.rowCount ?? 0);
    });

    return {
      module: this.moduleName,
      recordsDeleted: totalDeleted,
      success: true
    };
  }
}
