import fs from 'fs';
import { withUserContext, withPurgeContext } from '../../core/database/index.js';
import type { ModulePrivacyContract, ExportPayload, DeletionResult } from '../privacy/index.js';

export * from './contracts.js';
export * from './pipeline.js';
export * from './extractor.js';
export * from './drafts.js';

export class MultimodalPrivacyContract implements ModulePrivacyContract {
  public readonly moduleName = 'multimodal';

  async exportData(userId: string): Promise<ExportPayload> {
    const data = await withUserContext(userId, async (client) => {
      const artifacts = await client.query(
        `SELECT id, mime_type, byte_size, file_hash, image_kind, status, metadata, created_at, deleted_at
         FROM media_artifacts WHERE user_id = $1`,
        [userId]
      );

      const drafts = await client.query(
        `SELECT id, media_artifact_id, image_kind, status, extracted_fields, overall_confidence,
                requires_field_attention, consistency_flags, created_at, updated_at, committed_at
         FROM extraction_drafts WHERE user_id = $1`,
        [userId]
      );

      return {
        mediaArtifactsCount: artifacts.rows.length,
        mediaArtifacts: artifacts.rows,
        extractionDraftsCount: drafts.rows.length,
        extractionDrafts: drafts.rows
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
      // 1. Delete physical files from disk
      const pathsRes = await client.query(
        `SELECT storage_path FROM media_artifacts WHERE user_id = $1`,
        [userId]
      );

      for (const row of pathsRes.rows) {
        try {
          if (row.storage_path && fs.existsSync(row.storage_path)) {
            fs.unlinkSync(row.storage_path);
          }
        } catch {
          // ignore disk deletion error during purge
        }
      }

      // 2. Cascade delete database records
      const draftRes = await client.query(`DELETE FROM extraction_drafts WHERE user_id = $1`, [userId]);
      const artRes = await client.query(`DELETE FROM media_artifacts WHERE user_id = $1`, [userId]);

      recordsDeleted = (draftRes.rowCount ?? 0) + (artRes.rowCount ?? 0);
    });

    return {
      module: this.moduleName,
      recordsDeleted,
      success: true
    };
  }
}
