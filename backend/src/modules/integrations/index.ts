import { withUserContext, withPurgeContext } from '../../core/database/index.js';
import type { ModulePrivacyContract, ExportPayload, DeletionResult } from '../privacy/index.js';

export class IntegrationsPrivacyContract implements ModulePrivacyContract {
  public readonly moduleName = 'integrations';

  async exportData(userId: string): Promise<ExportPayload> {
    const data = await withUserContext(userId, async (client) => {
      const connections = await client.query(
        `SELECT id, provider, status, scopes, metadata, last_synced_at, created_at, updated_at
         FROM integration_connections WHERE user_id = $1`,
        [userId]
      );

      const batches = await client.query(
        `SELECT id, provider, status, records_count, duplicates_count, conflicts_count, sync_cursor, started_at, completed_at
         FROM import_batches WHERE user_id = $1`,
        [userId]
      );

      const dedupRecords = await client.query(
        `SELECT id, provider, external_record_id, dedup_hash, created_at
         FROM sync_dedup_records WHERE user_id = $1`,
        [userId]
      );

      return {
        connectionsCount: connections.rows.length,
        connections: connections.rows,
        importBatchesCount: batches.rows.length,
        importBatches: batches.rows,
        syncedRecordsCount: dedupRecords.rows.length,
        syncedRecords: dedupRecords.rows
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
    let recordsDeleted = 0;

    await withPurgeContext(userId, async (client) => {
      const delDedup = await client.query(`DELETE FROM sync_dedup_records WHERE user_id = $1`, [userId]);
      recordsDeleted += delDedup.rowCount || 0;

      const delBatches = await client.query(`DELETE FROM import_batches WHERE user_id = $1`, [userId]);
      recordsDeleted += delBatches.rowCount || 0;

      const delConns = await client.query(`DELETE FROM integration_connections WHERE user_id = $1`, [userId]);
      recordsDeleted += delConns.rowCount || 0;
    });

    return {
      module: this.moduleName,
      recordsDeleted,
      success: true
    };
  }
}
