import { describe, it, expect, beforeAll } from 'vitest';
import { runMigrations } from '../core/database/migrate.js';
import { withSystemContext } from '../core/database/index.js';
import { IdentityService } from '../modules/identity/service.js';
import { MeasurementsService } from '../modules/measurements/service.js';
import { GoalsService } from '../modules/goals/service.js';
import { AssistantMemoryService, AssistantPrivacyContract } from '../modules/assistant/index.js';
import { MediaPipeline, MultimodalPrivacyContract } from '../modules/multimodal/index.js';
import { IntegrationSyncService, IntegrationsPrivacyContract } from '../modules/integrations/index.js';
import {
  PrivacyOrchestrator,
  IdentityPrivacyContract,
  ProfilePrivacyContract,
  MeasurementsPrivacyContract
} from '../modules/privacy/index.js';
import fs from 'fs';

describe('Phase 6: End-to-End Privacy Verification (Blueprint §31.1 Gate 7, §32 Invariant 14)', () => {
  let purgeUserId: string;
  let testMediaPath: string;

  const validJpegBase64 =
    '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=';

  beforeAll(async () => {
    await runMigrations();

    // Register all domain privacy contracts
    PrivacyOrchestrator.registerModule(IdentityPrivacyContract);
    PrivacyOrchestrator.registerModule(ProfilePrivacyContract);
    PrivacyOrchestrator.registerModule(MeasurementsPrivacyContract);
    PrivacyOrchestrator.registerModule(new AssistantPrivacyContract());
    PrivacyOrchestrator.registerModule(new MultimodalPrivacyContract());
    PrivacyOrchestrator.registerModule(new IntegrationsPrivacyContract());

    // 1. Create User
    const regRes = await IdentityService.register(
      {
        email: `privacy_purge_${Date.now()}@example.com`,
        password: 'Password123!',
        dateOfBirth: '1985-06-20',
        heightCm: 177,
        sexForCalculation: 'male',
        locale: 'en',
        numeralSystem: 'western',
        consents: { termsOfService: true, healthDataProcessing: true, aiThirdPartyProcessing: true }
      },
      'corr-privacy-setup'
    );
    purgeUserId = regRes.user.id;

    // 2. Add Measurement Observation
    await MeasurementsService.recordObservation(
      purgeUserId,
      {
        typeCode: 'weight',
        value: 82.5,
        unit: 'kg',
        observedAt: new Date().toISOString(),
        originType: 'manual_entry',
        epistemicClass: 'measured',
        actor: 'user'
      },
      'corr-privacy-obs'
    );

    // 3. Add Goal
    const goalsService = new GoalsService();
    await goalsService.createGoal(
      purgeUserId,
      {
        goalType: 'weight_loss',
        targetMetricTypeCode: 'weight',
        startingValue: 82.5,
        targetValue: 75.0,
        startDate: '2026-10-01',
        targetDate: '2026-12-31',
        isPrimary: true
      }
    );

    // 4. Add Assistant Memory
    await AssistantMemoryService.saveMemory(
      purgeUserId,
      {
        category: 'preference',
        key: 'workout_time',
        value: 'Prefers morning workouts before breakfast'
      },
      undefined,
      'user_explicit'
    );

    // 5. Ingest Media Image
    const media = await MediaPipeline.ingestImage(
      purgeUserId,
      validJpegBase64,
      'image/jpeg',
      'scale_display'
    );
    testMediaPath = media.artifact.storagePath;

    // 6. Ingest Integration Batch
    await IntegrationSyncService.ingestBatch(
      purgeUserId,
      {
        provider: 'health_connect',
        records: [
          {
            externalRecordId: 'hc-e2e-1',
            typeCode: 'weight',
            value: 82.3,
            unit: 'kg',
            recordedAt: new Date().toISOString(),
            epistemicClass: 'measured'
          }
        ]
      },
      'corr-privacy-sync'
    );
  });

  it('exports comprehensive machine-readable GDPR data payload across all modules', async () => {
    const exportResult = await PrivacyOrchestrator.exportAllUserData(purgeUserId, 'corr-privacy-export');

    expect(exportResult).toBeDefined();
    expect(exportResult.userId).toBe(purgeUserId);
    expect(exportResult.exportDate).toBeDefined();

    // Verify all module sections are present in export
    const modules = exportResult.modules;
    expect(modules.identity).toBeDefined();
    expect(modules.profile).toBeDefined();
    expect(modules.measurements).toBeDefined();
    expect(modules.assistant).toBeDefined();
    expect(modules.multimodal).toBeDefined();
    expect(modules.integrations).toBeDefined();

    // Verify sensitive secrets are NEVER included
    const exportJsonStr = JSON.stringify(exportResult).toLowerCase();
    expect(exportJsonStr).not.toContain('password_hash');
    expect(exportJsonStr).not.toContain('gemini_api_key');
  });

  it('executes cascading account purge: deletes user, rows in all domain tables, and physical files', async () => {
    // Verify physical file exists before purge
    expect(fs.existsSync(testMediaPath)).toBe(true);

    // Execute purge
    const purgeResult = await PrivacyOrchestrator.purgeUserAccount(purgeUserId, 'corr-privacy-purge');
    expect(purgeResult.success).toBe(true);

    // Verify physical file was unlinked from disk
    expect(fs.existsSync(testMediaPath)).toBe(false);

    // Verify all user-scoped tables have 0 rows remaining under system context
    await withSystemContext(async (client) => {
      const userRes = await client.query('SELECT * FROM users WHERE id = $1', [purgeUserId]);
      expect(userRes.rows.length).toBe(0);

      const tablesToCheck = [
        'profiles',
        'consents',
        'credentials',
        'sessions',
        'observations',
        'provenance_records',
        'goals',
        'goal_versions',
        'health_snapshots',
        'assistant_memories',
        'conversations',
        'action_proposals',
        'media_artifacts',
        'extraction_drafts',
        'integration_connections',
        'import_batches',
        'sync_dedup_records'
      ];

      for (const table of tablesToCheck) {
        const res = await client.query(`SELECT COUNT(*)::int as count FROM ${table} WHERE user_id = $1`, [purgeUserId]);
        expect(res.rows[0].count).toBe(0);
      }
    });
  });
});
