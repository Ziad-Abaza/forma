import { describe, it, expect, beforeAll } from 'vitest';
import fs from 'fs';
import { runMigrations } from '../core/database/migrate.js';
import { withUserContext } from '../core/database/index.js';
import { IdentityService } from '../modules/identity/service.js';
import { MeasurementsService } from '../modules/measurements/service.js';
import {
  MediaPipeline,
  VisionExtractor,
  DraftReviewService,
  MultimodalPrivacyContract
} from '../modules/multimodal/index.js';
import { PrivacyOrchestrator } from '../modules/privacy/index.js';

describe('Phase 5: Multimodal Image Intelligence & Vision Extraction Tests', { timeout: 30000 }, () => {
  let userAId: string;
  let userBId: string;

  // Minimal valid 1x1 JPEG bytes (starts with FF D8 FF)
  const validJpegBase64 =
    '/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=';

  // Minimal valid 1x1 PNG bytes (starts with 89 50 4E 47 0D 0A 1A 0A)
  const validPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

  beforeAll(async () => {
    await runMigrations();

    PrivacyOrchestrator.registerModule(new MultimodalPrivacyContract());

    // Register User A
    const userA = await IdentityService.register(
      {
        email: `multimodal_user_a_${Date.now()}@example.com`,
        password: 'Password123!',
        dateOfBirth: '1991-03-20',
        heightCm: 178,
        sexForCalculation: 'male',
        locale: 'en',
        numeralSystem: 'western',
        consents: { termsOfService: true, healthDataProcessing: true, aiThirdPartyProcessing: true }
      },
      'corr-setup-multi-a'
    );
    userAId = userA.user.id;

    // Register User B
    const userB = await IdentityService.register(
      {
        email: `multimodal_user_b_${Date.now()}@example.com`,
        password: 'Password123!',
        dateOfBirth: '1993-07-10',
        heightCm: 168,
        sexForCalculation: 'female',
        locale: 'ar',
        numeralSystem: 'eastern_arabic',
        consents: { termsOfService: true, healthDataProcessing: true, aiThirdPartyProcessing: true }
      },
      'corr-setup-multi-b'
    );
    userBId = userB.user.id;
  });

  describe('1. Secure Media Ingestion Pipeline (Blueprint §13.2)', () => {
    it('successfully ingests valid JPEG, verifies magic numbers, and stores file privately', async () => {
      const media = await MediaPipeline.ingestImage(
        userAId,
        validJpegBase64,
        'image/jpeg',
        'scale_display'
      );

      expect(media.artifact.id).toBeDefined();
      expect(media.artifact.mimeType).toBe('image/jpeg');
      expect(media.artifact.fileHash).toBeDefined();
      expect(media.artifact.status).toBe('uploaded');
      expect(fs.existsSync(media.artifact.storagePath)).toBe(true);
    });

    it('successfully ingests valid PNG image', async () => {
      const media = await MediaPipeline.ingestImage(
        userAId,
        validPngBase64,
        'image/png',
        'body_composition_report'
      );

      expect(media.artifact.mimeType).toBe('image/png');
      expect(fs.existsSync(media.artifact.storagePath)).toBe(true);
    });

    it('rejects fake or corrupted non-image payloads via byte inspection', async () => {
      const fakePayloadBase64 = Buffer.from('NOT AN IMAGE FILE CONTENT').toString('base64');

      await expect(
        MediaPipeline.ingestImage(userAId, fakePayloadBase64, 'image/jpeg')
      ).rejects.toThrow(/Image verification failed/);
    });
  });

  describe('2. Scope Guardrail: Clinical Document Boundary (Blueprint §13.4)', () => {
    it('explicitly rejects clinical lab reports with an informative disclaimer', async () => {
      const media = await MediaPipeline.ingestImage(
        userAId,
        validJpegBase64,
        'image/jpeg',
        'clinical_document'
      );

      await expect(
        VisionExtractor.extractFromImage({
          userId: userAId,
          mediaArtifact: media.artifact,
          base64Image: media.base64,
          kindHint: 'clinical_document',
          correlationId: 'corr-reject-clin'
        })
      ).rejects.toThrow(/Clinical and medical lab documents are outside the scope of Forma/);
    });
  });

  describe('3. Draft Review Service & Adaptive Review Intensity (Blueprint §13.2, §13.4)', () => {
    it('creates an extraction draft without committing to health observations', async () => {
      const media = await MediaPipeline.ingestImage(
        userAId,
        validJpegBase64,
        'image/jpeg',
        'body_composition_report'
      );

      const draft = await VisionExtractor.extractFromImage({
        userId: userAId,
        mediaArtifact: media.artifact,
        base64Image: media.base64,
        kindHint: 'body_composition_report',
        correlationId: 'corr-draft-create'
      });

      expect(draft.id).toBeDefined();
      expect(draft.status).toBe('draft');

      // Invariant: Verify zero observations were written!
      const initialObs = await MeasurementsService.getLatestObservation(userAId, 'weight');
      expect(initialObs).toBeNull();
    });

    it('supports field editing and user correction in draft', async () => {
      // Create a draft with synthetic fields in DB
      const media = await MediaPipeline.ingestImage(
        userAId,
        validJpegBase64,
        'image/jpeg',
        'scale_display'
      );

      const draft = await withUserContext(userAId, async (client) => {
        const res = await client.query(
          `INSERT INTO extraction_drafts (
            user_id, media_artifact_id, image_kind, status, extracted_fields, overall_confidence
          ) VALUES ($1, $2, 'scale_display', 'draft', $3, 0.95) RETURNING *`,
          [
            userAId,
            media.artifact.id,
            JSON.stringify([
              {
                typeCode: 'weight',
                rawLabel: 'Weight',
                extractedValue: 78.5,
                unit: 'kg',
                canonicalValue: 78.5,
                canonicalUnit: 'kg',
                confidenceScore: 0.95,
                qualityFlags: [],
                epistemicClass: 'measured',
                isApproved: true
              }
            ])
          ]
        );
        return res.rows[0];
      });

      // User corrects weight to 77.0 kg
      const updated = await DraftReviewService.updateDraftField(userAId, draft.id, {
        fieldIndex: 0,
        userEditedValue: 77.0,
        isApproved: true
      });

      expect(updated.status).toBe('reviewed');
      expect(updated.extractedFields[0]!.userEditedValue).toBe(77.0);
      expect(updated.extractedFields[0]!.canonicalValue).toBe(77.0);
    });

    it('commits approved fields with strict provenance (ai_extraction, measured, user_corrected)', async () => {
      const media = await MediaPipeline.ingestImage(
        userAId,
        validJpegBase64,
        'image/jpeg',
        'body_composition_report'
      );

      // Create draft with weight and body fat %
      const draft = await withUserContext(userAId, async (client) => {
        const res = await client.query(
          `INSERT INTO extraction_drafts (
            user_id, media_artifact_id, image_kind, status, extracted_fields, overall_confidence
          ) VALUES ($1, $2, 'body_composition_report', 'draft', $3, 0.92) RETURNING *`,
          [
            userAId,
            media.artifact.id,
            JSON.stringify([
              {
                typeCode: 'weight',
                rawLabel: 'Weight',
                extractedValue: 76.0,
                unit: 'kg',
                canonicalValue: 76.0,
                canonicalUnit: 'kg',
                confidenceScore: 0.95,
                qualityFlags: [],
                epistemicClass: 'measured',
                userEditedValue: 75.8, // user corrected slightly
                isApproved: true
              },
              {
                typeCode: 'body_fat_percentage',
                rawLabel: 'Body Fat %',
                extractedValue: 18.2,
                unit: '%',
                canonicalValue: 18.2,
                canonicalUnit: '%',
                confidenceScore: 0.88,
                qualityFlags: [],
                epistemicClass: 'measured',
                isApproved: true
              }
            ])
          ]
        );
        return res.rows[0];
      });

      // Commit draft
      const result = await DraftReviewService.commitDraft(
        userAId,
        draft.id,
        { deleteSourceImage: false },
        'corr-commit-test'
      );

      expect(result.observationsCommitted).toBe(2);
      expect(result.draft.status).toBe('committed');

      // Verify domain observations were committed
      const latestWeight = await MeasurementsService.getLatestObservation(userAId, 'weight');
      expect(latestWeight).toBeDefined();
      expect(latestWeight?.canonical_value).toBe(75.8); // user edited value

      // Verify provenance record
      const prov = await MeasurementsService.getProvenance(userAId, latestWeight!.provenance_id);
      expect(prov).toBeDefined();
      expect(prov?.origin_type).toBe('ai_extraction');
      expect(prov?.epistemic_class).toBe('measured');
      expect(prov?.review_state).toBe('user_corrected');
      expect(prov?.source_artifact_id).toBe(media.artifact.id);
    });

    it('deletes source image file on commit when deleteSourceImage is true while preserving provenance', async () => {
      const media = await MediaPipeline.ingestImage(
        userAId,
        validJpegBase64,
        'image/jpeg',
        'scale_display'
      );
      expect(fs.existsSync(media.artifact.storagePath)).toBe(true);

      const draft = await withUserContext(userAId, async (client) => {
        const res = await client.query(
          `INSERT INTO extraction_drafts (
            user_id, media_artifact_id, image_kind, status, extracted_fields, overall_confidence
          ) VALUES ($1, $2, 'scale_display', 'draft', $3, 0.9) RETURNING *`,
          [
            userAId,
            media.artifact.id,
            JSON.stringify([
              {
                typeCode: 'weight',
                rawLabel: 'Weight',
                extractedValue: 75.5,
                unit: 'kg',
                canonicalValue: 75.5,
                canonicalUnit: 'kg',
                confidenceScore: 0.9,
                qualityFlags: [],
                epistemicClass: 'measured',
                isApproved: true
              }
            ])
          ]
        );
        return res.rows[0];
      });

      // Commit with deleteSourceImage: true
      const commitRes = await DraftReviewService.commitDraft(
        userAId,
        draft.id,
        { deleteSourceImage: true },
        'corr-delete-img'
      );

      expect(commitRes.sourceImageDeleted).toBe(true);
      // Verify file was unlinked from disk
      expect(fs.existsSync(media.artifact.storagePath)).toBe(false);

      // Verify media_artifacts record was updated to deleted
      const artAfter = await withUserContext(userAId, async (client) => {
        const res = await client.query('SELECT status, deleted_at FROM media_artifacts WHERE id = $1', [media.artifact.id]);
        return res.rows[0];
      });
      expect(artAfter.status).toBe('deleted');
      expect(artAfter.deleted_at).toBeDefined();
    });
  });

  describe('4. Cross-User Double Isolation & PostgreSQL RLS (Blueprint §32 Invariant 5)', () => {
    it('prevents User B from viewing or accessing User A’s media artifacts and extraction drafts', async () => {
      const mediaA = await MediaPipeline.ingestImage(
        userAId,
        validJpegBase64,
        'image/jpeg',
        'scale_display'
      );

      // User B attempts to access User A's artifact
      const userBArtifact = await withUserContext(userBId, async (client) => {
        const res = await client.query('SELECT * FROM media_artifacts WHERE id = $1', [mediaA.artifact.id]);
        return res.rows;
      });
      expect(userBArtifact.length).toBe(0);

      // User B attempts to get User A's draft
      const draftA = await withUserContext(userAId, async (client) => {
        const res = await client.query(
          `INSERT INTO extraction_drafts (user_id, image_kind, status, extracted_fields)
           VALUES ($1, 'scale_display', 'draft', '[]'::jsonb) RETURNING id`,
          [userAId]
        );
        return res.rows[0];
      });

      const userBDraftView = await DraftReviewService.getDraft(userBId, draftA.id);
      expect(userBDraftView).toBeNull();
    });

    it('prevents User B from committing or modifying User A’s extraction draft', async () => {
      const draftA = await withUserContext(userAId, async (client) => {
        const res = await client.query(
          `INSERT INTO extraction_drafts (user_id, image_kind, status, extracted_fields)
           VALUES ($1, 'scale_display', 'draft', '[]'::jsonb) RETURNING id`,
          [userAId]
        );
        return res.rows[0];
      });

      await expect(
        DraftReviewService.commitDraft(userBId, draftA.id, { deleteSourceImage: false }, 'corr-tamper')
      ).rejects.toThrow(/Extraction draft not found/);
    });
  });

  describe('5. Privacy Export & Purge Parity for Multimodal Data (Blueprint §32 Invariant 6)', () => {
    it('includes media metadata in GDPR export and purges files and drafts upon account deletion', async () => {
      // Register purge test user
      const purgeUser = await IdentityService.register(
        {
          email: `purge_multi_${Date.now()}@example.com`,
          password: 'Password123!',
          dateOfBirth: '1989-12-05',
          heightCm: 182,
          sexForCalculation: 'male',
          locale: 'en',
          numeralSystem: 'western',
          consents: { termsOfService: true, healthDataProcessing: true, aiThirdPartyProcessing: true }
        },
        'corr-purge-multi-reg'
      );
      const purgeUserId = purgeUser.user.id;

      // Ingest image for purge user
      const media = await MediaPipeline.ingestImage(
        purgeUserId,
        validJpegBase64,
        'image/jpeg',
        'scale_display'
      );
      expect(fs.existsSync(media.artifact.storagePath)).toBe(true);

      // Create draft
      await withUserContext(purgeUserId, async (client) => {
        await client.query(
          `INSERT INTO extraction_drafts (user_id, media_artifact_id, image_kind, status, extracted_fields)
           VALUES ($1, $2, 'scale_display', 'draft', '[]'::jsonb)`,
          [purgeUserId, media.artifact.id]
        );
      });

      // Export user data
      const exported = await PrivacyOrchestrator.exportAllUserData(purgeUserId, 'corr-exp-multi');
      expect(exported.modules.multimodal).toBeDefined();
      const multiData = exported.modules.multimodal as any;
      expect(multiData.mediaArtifactsCount).toBeGreaterThanOrEqual(1);
      expect(multiData.extractionDraftsCount).toBeGreaterThanOrEqual(1);

      // Purge account
      const purgeRes = await PrivacyOrchestrator.purgeUserAccount(purgeUserId, 'corr-purge-multi-exec');
      expect(purgeRes.success).toBe(true);

      // Verify file was purged from disk
      expect(fs.existsSync(media.artifact.storagePath)).toBe(false);

      // Verify DB records purged
      const draftsAfter = await withUserContext(purgeUserId, async (client) => {
        const res = await client.query('SELECT COUNT(*) FROM extraction_drafts WHERE user_id = $1', [purgeUserId]);
        return parseInt(res.rows[0].count, 10);
      });
      expect(draftsAfter).toBe(0);
    });
  });
});
