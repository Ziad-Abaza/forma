import crypto from 'crypto';
import { withUserContext } from '../../core/database/index.js';
import { MeasurementsService } from '../measurements/service.js';
import {
  IntegrationProvider,
  SyncBatchRequest,
  SyncBatchResult,
  IntegrationConnectionRecord
} from './contracts.js';

// Epistemic Precedence Hierarchy (Blueprint §13.4, §28.1)
const EPISTEMIC_PRECEDENCE: Record<string, number> = {
  measured: 4,
  calculated: 3,
  asserted: 2,
  estimated: 1
};

export class IntegrationSyncService {
  /**
   * Connects or updates an external integration provider for a user
   */
  static async connectProvider(
    userId: string,
    provider: IntegrationProvider,
    scopes: string[] = [],
    metadata: Record<string, unknown> = {}
  ): Promise<IntegrationConnectionRecord> {
    return await withUserContext(userId, async (client) => {
      const res = await client.query(
        `INSERT INTO integration_connections (
          user_id, provider, status, scopes, metadata, updated_at
        ) VALUES ($1, $2, 'connected', $3, $4, NOW())
        ON CONFLICT (user_id, provider) DO UPDATE SET
          status = 'connected',
          scopes = EXCLUDED.scopes,
          metadata = EXCLUDED.metadata,
          updated_at = NOW()
        RETURNING *`,
        [userId, provider, JSON.stringify(scopes), JSON.stringify(metadata)]
      );

      const row = res.rows[0];
      return {
        id: row.id,
        userId: row.user_id,
        provider: row.provider,
        status: row.status,
        scopes: row.scopes || [],
        metadata: row.metadata || {},
        lastSyncedAt: row.last_synced_at?.toISOString(),
        createdAt: row.created_at.toISOString(),
        updatedAt: row.updated_at.toISOString()
      };
    });
  }

  /**
   * Disconnects / revokes an integration provider
   */
  static async disconnectProvider(userId: string, provider: IntegrationProvider): Promise<void> {
    await withUserContext(userId, async (client) => {
      await client.query(
        `UPDATE integration_connections
         SET status = 'revoked', updated_at = NOW()
         WHERE user_id = $1 AND provider = $2`,
        [userId, provider]
      );
    });
  }

  /**
   * Retrieves all integration connections for a user
   */
  static async getConnections(userId: string): Promise<IntegrationConnectionRecord[]> {
    return await withUserContext(userId, async (client) => {
      const res = await client.query(
        `SELECT * FROM integration_connections WHERE user_id = $1 ORDER BY created_at ASC`,
        [userId]
      );

      return res.rows.map(row => ({
        id: row.id,
        userId: row.user_id,
        provider: row.provider,
        status: row.status,
        scopes: row.scopes || [],
        metadata: row.metadata || {},
        lastSyncedAt: row.last_synced_at?.toISOString(),
        createdAt: row.created_at.toISOString(),
        updatedAt: row.updated_at.toISOString()
      }));
    });
  }

  /**
   * Generates a deterministic deduplication hash for an external record
   */
  static computeDedupHash(
    provider: string,
    externalRecordId: string,
    typeCode: string,
    recordedAt: string
  ): string {
    return crypto
      .createHash('sha256')
      .update(`${provider}:${externalRecordId}:${typeCode}:${recordedAt}`)
      .digest('hex');
  }

  /**
   * Ingests a batch of wearable or health records with idempotent deduplication and conflict resolution
   */
  static async ingestBatch(
    userId: string,
    req: SyncBatchRequest,
    correlationId: string
  ): Promise<SyncBatchResult> {
    return await withUserContext(userId, async (client) => {
      // 1. Ensure or retrieve active connection
      let connectionRes = await client.query(
        `SELECT id FROM integration_connections WHERE user_id = $1 AND provider = $2`,
        [userId, req.provider]
      );

      let connectionId: string | null = null;
      if (connectionRes.rows.length === 0) {
        const newConn = await client.query(
          `INSERT INTO integration_connections (user_id, provider, status)
           VALUES ($1, $2, 'connected') RETURNING id`,
          [userId, req.provider]
        );
        connectionId = newConn.rows[0].id;
      } else {
        connectionId = connectionRes.rows[0].id;
      }

      // 2. Initialize import batch
      const batchRes = await client.query(
        `INSERT INTO import_batches (
          user_id, connection_id, provider, status, sync_cursor, started_at
        ) VALUES ($1, $2, $3, 'processing', $4, NOW()) RETURNING id`,
        [userId, connectionId, req.provider, req.syncCursor || null]
      );
      const batchId = batchRes.rows[0].id;

      let inserted = 0;
      let deduplicated = 0;
      let supersededConflicts = 0;
      let rejected = 0;

      // 3. Process each incoming record
      for (const rec of req.records) {
        const dedupHash = this.computeDedupHash(
          req.provider,
          rec.externalRecordId,
          rec.typeCode,
          rec.recordedAt
        );

        // Check if already synced (Idempotent Deduplication - §28.1)
        const dedupCheck = await client.query(
          `SELECT id FROM sync_dedup_records WHERE user_id = $1 AND dedup_hash = $2`,
          [userId, dedupHash]
        );

        if (dedupCheck.rows.length > 0) {
          deduplicated++;
          continue;
        }

        // Validate measurement type exists in catalog
        const catalogCheck = await client.query(
          `SELECT code, allowed_units FROM measurement_types WHERE code = $1`,
          [rec.typeCode]
        );

        if (catalogCheck.rows.length === 0) {
          // Unknown catalog metric -> reject gracefully without aborting batch
          rejected++;
          continue;
        }

        const allowedUnits: string[] = catalogCheck.rows[0].allowed_units;
        const normalizedUnit = rec.unit === '%' ? 'percent' : rec.unit;
        if (!allowedUnits.includes(normalizedUnit)) {
          rejected++;
          continue;
        }

        // Check for existing overlapping active observations (+/- 120s window)
        const existingObsRes = await client.query(
          `SELECT o.id, o.type_code, o.canonical_value, o.canonical_unit, o.observed_at,
                  p.epistemic_class, p.origin_type
           FROM observations o
           JOIN provenance_records p ON o.provenance_id = p.id
           WHERE o.user_id = $1
             AND o.type_code = $2
             AND o.status = 'active'
             AND ABS(EXTRACT(EPOCH FROM (o.observed_at - $3::timestamptz))) <= 120
           ORDER BY o.recorded_at DESC
           LIMIT 1`,
          [userId, rec.typeCode, rec.recordedAt]
        );

        const existingObs = existingObsRes.rows[0];
        let observationId: string;

        if (existingObs) {
          const existingPrecedence = EPISTEMIC_PRECEDENCE[existingObs.epistemic_class] || 1;
          const incomingPrecedence = EPISTEMIC_PRECEDENCE[rec.epistemicClass] || 4;

          if (incomingPrecedence >= existingPrecedence) {
            // Incoming record has higher or equal epistemic precedence:
            // Supersede existing observation, preserving complete history (Blueprint §28.1, §32 Invariant 3)
            const superseded = await MeasurementsService.supersedeObservation(
              userId,
              {
                previousObservationId: existingObs.id,
                newValue: rec.value,
                newUnit: normalizedUnit,
                observedAt: rec.recordedAt,
                correctionReason: `superseded_by_${req.provider}_device_sync`
              },
              correlationId
            );
            observationId = superseded.newObservation.id;
            supersededConflicts++;
          } else {
            // Existing observation has higher epistemic precedence (e.g. manual medical/clinical reading vs device estimate)
            // Do not overwrite; skip inserting this record
            rejected++;
            continue;
          }
        } else {
          // No conflicting observation: record clean measurement
          const recorded = await MeasurementsService.recordObservation(
            userId,
            {
              typeCode: rec.typeCode,
              value: rec.value,
              unit: normalizedUnit,
              observedAt: rec.recordedAt,
              originType: 'device_import',
              epistemicClass: rec.epistemicClass,
              actor: 'system',
              confidenceScore: 0.98,
              sourceArtifactId: batchId,
              reviewState: 'unreviewed'
            },
            correlationId
          );
          observationId = recorded.observation.id;
          inserted++;
        }

        // Record deduplication hash
        await client.query(
          `INSERT INTO sync_dedup_records (
            user_id, connection_id, batch_id, observation_id, provider, external_record_id, dedup_hash
          ) VALUES ($1, $2, $3, $4, $5, $6, $7)`,
          [
            userId,
            connectionId,
            batchId,
            observationId,
            req.provider,
            rec.externalRecordId,
            dedupHash
          ]
        );
      }

      // 4. Update import batch summary
      await client.query(
        `UPDATE import_batches SET
          status = 'completed',
          records_count = $1,
          duplicates_count = $2,
          conflicts_count = $3,
          completed_at = NOW()
        WHERE id = $4`,
        [req.records.length, deduplicated, supersededConflicts, batchId]
      );

      // 5. Update last_synced_at on integration connection
      await client.query(
        `UPDATE integration_connections
         SET last_synced_at = NOW(), updated_at = NOW()
         WHERE id = $1`,
        [connectionId]
      );

      return {
        batchId,
        provider: req.provider,
        totalProcessed: req.records.length,
        inserted,
        deduplicated,
        supersededConflicts,
        rejected,
        syncCursor: req.syncCursor
      };
    });
  }
}
