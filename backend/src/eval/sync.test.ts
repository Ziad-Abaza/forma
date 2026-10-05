import { describe, it, expect, beforeAll } from 'vitest';
import { runMigrations } from '../core/database/migrate.js';
import { withUserContext } from '../core/database/index.js';
import { IdentityService } from '../modules/identity/service.js';
import { IntegrationSyncService } from '../modules/integrations/sync.js';
import { MeasurementsService } from '../modules/measurements/service.js';
import crypto from 'crypto';

describe('Phase 6: Integrations, Wearables Ingestion & Conflict Resolution Tests', () => {
  let userAId: string;
  let userBId: string;

  beforeAll(async () => {
    await runMigrations();

    const userA = await IdentityService.register(
      {
        email: `sync_user_a_${Date.now()}@example.com`,
        password: 'Password123!',
        dateOfBirth: '1990-05-15',
        heightCm: 175,
        sexForCalculation: 'male',
        locale: 'en',
        numeralSystem: 'western',
        consents: { termsOfService: true, healthDataProcessing: true, aiThirdPartyProcessing: true }
      },
      'corr-setup-sync-a'
    );
    userAId = userA.user.id;

    const userB = await IdentityService.register(
      {
        email: `sync_user_b_${Date.now()}@example.com`,
        password: 'Password123!',
        dateOfBirth: '1992-08-20',
        heightCm: 165,
        sexForCalculation: 'female',
        locale: 'en',
        numeralSystem: 'western',
        consents: { termsOfService: true, healthDataProcessing: true, aiThirdPartyProcessing: true }
      },
      'corr-setup-sync-b'
    );
    userBId = userB.user.id;
  });

  describe('1. Provider Connections & Scopes Management', () => {
    it('connects a health provider with granted scopes and persists metadata', async () => {
      const conn = await IntegrationSyncService.connectProvider(
        userAId,
        'health_connect',
        ['weight', 'body_fat_percentage'],
        { deviceModel: 'Pixel Watch 3', osVersion: 'Android 15' }
      );

      expect(conn).toBeDefined();
      expect(conn.provider).toBe('health_connect');
      expect(conn.status).toBe('connected');
      expect(conn.scopes).toContain('weight');
      expect(conn.metadata.deviceModel).toBe('Pixel Watch 3');

      const connections = await IntegrationSyncService.getConnections(userAId);
      expect(connections.length).toBeGreaterThanOrEqual(1);
      const found = connections.find(c => c.provider === 'health_connect');
      expect(found).toBeDefined();
    });

    it('revokes/disconnects an integration provider', async () => {
      await IntegrationSyncService.disconnectProvider(userAId, 'health_connect');
      const connections = await IntegrationSyncService.getConnections(userAId);
      const found = connections.find(c => c.provider === 'health_connect');
      expect(found?.status).toBe('revoked');
    });
  });

  describe('2. Idempotent Ingestion & Deduplication (Blueprint §28.1)', () => {
    it('ingests wearable records with provenance and dedupes identical re-syncs', async () => {
      const recordedAt = new Date().toISOString();
      const extRecordId = `ext-${crypto.randomUUID()}`;

      // First Ingest
      const res1 = await IntegrationSyncService.ingestBatch(
        userAId,
        {
          provider: 'apple_health',
          syncCursor: 'cursor-v1',
          records: [
            {
              externalRecordId: extRecordId,
              typeCode: 'weight',
              value: 78.4,
              unit: 'kg',
              recordedAt,
              sourceDeviceId: 'AppleWatch9,1',
              epistemicClass: 'measured'
            }
          ]
        },
        'corr-sync-1'
      );

      expect(res1.inserted).toBe(1);
      expect(res1.deduplicated).toBe(0);

      // Verify measurement recorded with complete provenance
      const latestWeight = await MeasurementsService.getLatestObservation(userAId, 'weight');
      expect(latestWeight).toBeDefined();
      expect(latestWeight?.canonical_value).toBe(78.4);

      const prov = await MeasurementsService.getProvenance(userAId, latestWeight!.provenance_id);
      expect(prov).toBeDefined();
      expect(prov?.origin_type).toBe('device_import');
      expect(prov?.epistemic_class).toBe('measured');
      expect(prov?.source_artifact_id).toBe(res1.batchId);

      // Second Ingest with the exact same record (Re-sync idempotency test)
      const res2 = await IntegrationSyncService.ingestBatch(
        userAId,
        {
          provider: 'apple_health',
          syncCursor: 'cursor-v2',
          records: [
            {
              externalRecordId: extRecordId,
              typeCode: 'weight',
              value: 78.4,
              unit: 'kg',
              recordedAt,
              sourceDeviceId: 'AppleWatch9,1',
              epistemicClass: 'measured'
            }
          ]
        },
        'corr-sync-2'
      );

      expect(res2.inserted).toBe(0);
      expect(res2.deduplicated).toBe(1); // Successfully deduplicated!
    });
  });

  describe('3. Epistemic Precedence & Conflict Resolution (Blueprint §28.1, §32 Invariant 3)', () => {
    it('supersedes an estimated/asserted observation when a direct measured device reading arrives', async () => {
      const recordedAt = new Date().toISOString();

      // 1. User records a rough estimate / manual observation
      const manualRecord = await MeasurementsService.recordObservation(
        userAId,
        {
          typeCode: 'body_fat_percentage',
          value: 19.5,
          unit: 'percent',
          observedAt: recordedAt,
          originType: 'manual_entry',
          epistemicClass: 'estimated', // lower precedence
          actor: 'user'
        },
        'corr-manual-est'
      );
      expect(manualRecord.observation.status).toBe('active');

      // 2. Direct DEXA / smart scale sync arrives with measured reading at the same timestamp
      const syncRes = await IntegrationSyncService.ingestBatch(
        userAId,
        {
          provider: 'withings',
          records: [
            {
              externalRecordId: `withings-${crypto.randomUUID()}`,
              typeCode: 'body_fat_percentage',
              value: 18.2,
              unit: 'percent',
              recordedAt,
              sourceDeviceId: 'BodyScan-Scale',
              epistemicClass: 'measured' // higher precedence
            }
          ]
        },
        'corr-scale-sync'
      );

      expect(syncRes.supersededConflicts).toBe(1);

      // Verify the manual observation was superseded (status = 'superseded', not deleted)
      const manualAfter = await withUserContext(userAId, async (client) => {
        const res = await client.query('SELECT status, superseded_by FROM observations WHERE id = $1', [
          manualRecord.observation.id
        ]);
        return res.rows[0];
      });

      expect(manualAfter.status).toBe('superseded');
      expect(manualAfter.superseded_by).toBeDefined();

      // Verify the new active observation is the measured one
      const latestBodyFat = await MeasurementsService.getLatestObservation(userAId, 'body_fat_percentage');
      expect(latestBodyFat?.canonical_value).toBe(18.2);
    });

    it('preserves authoritative measured observation if a lower precedence estimate arrives', async () => {
      const recordedAt = new Date().toISOString();

      // 1. Direct measured reading exists
      const measured = await MeasurementsService.recordObservation(
        userAId,
        {
          typeCode: 'weight',
          value: 75.0,
          unit: 'kg',
          observedAt: recordedAt,
          originType: 'manual_entry',
          epistemicClass: 'measured',
          actor: 'user'
        },
        'corr-measured'
      );

      // 2. Incoming estimated reading arrives at the same timestamp
      const syncRes = await IntegrationSyncService.ingestBatch(
        userAId,
        {
          provider: 'fitbit',
          records: [
            {
              externalRecordId: `fitbit-${crypto.randomUUID()}`,
              typeCode: 'weight',
              value: 74.0,
              unit: 'kg',
              recordedAt,
              epistemicClass: 'estimated' // lower precedence than measured
            }
          ]
        },
        'corr-fitbit-sync'
      );

      // Precedence rejected: incoming estimate does not overwrite established measurement
      expect(syncRes.rejected).toBe(1);
      expect(syncRes.supersededConflicts).toBe(0);

      // Original measured observation remains active
      const activeObs = await withUserContext(userAId, async (client) => {
        const res = await client.query('SELECT status FROM observations WHERE id = $1', [measured.observation.id]);
        return res.rows[0];
      });
      expect(activeObs.status).toBe('active');
    });
  });

  describe('4. Cross-User Double Isolation & PostgreSQL RLS (Blueprint §32 Invariant 5)', () => {
    it('prevents User B from querying User A’s integration connections and batches', async () => {
      // Connect provider for User A
      await IntegrationSyncService.connectProvider(userAId, 'oura', ['sleep', 'readiness']);

      // Attempt to access User A's connections as User B
      const userBConns = await withUserContext(userBId, async (client) => {
        const res = await client.query('SELECT * FROM integration_connections WHERE user_id = $1', [userAId]);
        return res.rows;
      });

      // RLS filters out rows of User A
      expect(userBConns.length).toBe(0);
    });
  });
});
