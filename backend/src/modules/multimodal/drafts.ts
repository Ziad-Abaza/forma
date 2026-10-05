import fs from 'fs';
import { withUserContext } from '../../core/database/index.js';
import { normalizeToCanonical } from '../../core/units/index.js';
import { MeasurementsService } from '../measurements/service.js';
import { AuditService } from '../audit/index.js';
import {
  type ExtractionDraft,
  type ExtractedField,
  type UpdateDraftFieldRequest,
  type CommitDraftRequest
} from './contracts.js';
import { mapExtractionDraftRow } from './extractor.js';

export interface CommitDraftResult {
  draft: ExtractionDraft;
  observationsCommitted: number;
  sourceImageDeleted: boolean;
}

export class DraftReviewService {
  /**
   * Retrieves a draft by ID scoped to the authenticated user.
   */
  static async getDraft(userId: string, draftId: string): Promise<ExtractionDraft | null> {
    return await withUserContext(userId, async (client) => {
      const res = await client.query(
        `SELECT * FROM extraction_drafts WHERE id = $1 AND user_id = $2`,
        [draftId, userId]
      );
      if (res.rows.length === 0) return null;
      return mapExtractionDraftRow(res.rows[0]);
    });
  }

  /**
   * Updates an extracted field in a draft (user correction or approval toggle).
   */
  static async updateDraftField(
    userId: string,
    draftId: string,
    req: UpdateDraftFieldRequest
  ): Promise<ExtractionDraft> {
    const draft = await this.getDraft(userId, draftId);
    if (!draft) {
      throw new Error(`Extraction draft not found: ${draftId}`);
    }

    if (draft.status !== 'draft' && draft.status !== 'reviewed') {
      throw new Error(`Cannot modify draft with status '${draft.status}'`);
    }

    const fields = [...draft.extractedFields];
    if (req.fieldIndex < 0 || req.fieldIndex >= fields.length) {
      throw new Error(`Field index ${req.fieldIndex} is out of bounds (total fields: ${fields.length})`);
    }

    const target = { ...fields[req.fieldIndex] } as ExtractedField;

    if (req.userEditedValue !== undefined) {
      target.userEditedValue = req.userEditedValue;
      try {
        const norm = normalizeToCanonical(req.userEditedValue, target.userEditedUnit || target.unit);
        target.canonicalValue = norm.canonicalValue;
        target.canonicalUnit = norm.canonicalUnit;
      } catch {
        // preserve original canonical if normalization fails
      }
    }

    if (req.userEditedUnit !== undefined) {
      target.userEditedUnit = req.userEditedUnit;
      try {
        const norm = normalizeToCanonical(target.userEditedValue ?? target.extractedValue, req.userEditedUnit);
        target.canonicalValue = norm.canonicalValue;
        target.canonicalUnit = norm.canonicalUnit;
      } catch {
        // preserve original
      }
    }

    if (req.isApproved !== undefined) {
      target.isApproved = req.isApproved;
    }

    fields[req.fieldIndex] = target;

    return await withUserContext(userId, async (client) => {
      const res = await client.query(
        `UPDATE extraction_drafts
         SET extracted_fields = $1, status = 'reviewed', updated_at = NOW()
         WHERE id = $2 AND user_id = $3
         RETURNING *`,
        [JSON.stringify(fields), draftId, userId]
      );
      return mapExtractionDraftRow(res.rows[0]);
    });
  }

  /**
   * Commits approved draft fields to the health record with full data provenance.
   * Enforces Blueprint §13.3 Invariant: AI extraction never auto-saves. Review is mandatory.
   * Enforces Blueprint §13.2 Rule 10: User choice to delete source image on commit while preserving provenance.
   */
  static async commitDraft(
    userId: string,
    draftId: string,
    options: CommitDraftRequest,
    correlationId: string
  ): Promise<CommitDraftResult> {
    const draft = await this.getDraft(userId, draftId);
    if (!draft) {
      throw new Error(`Extraction draft not found: ${draftId}`);
    }

    if (draft.status === 'committed') {
      throw new Error(`Extraction draft ${draftId} has already been committed`);
    }

    if (draft.status === 'discarded') {
      throw new Error(`Extraction draft ${draftId} has been discarded and cannot be committed`);
    }

    const approvedFields = draft.extractedFields.filter((f) => f.isApproved);
    if (approvedFields.length === 0) {
      throw new Error('Cannot commit extraction draft: no fields are marked as approved');
    }

    const observedAt = options.observedAt || new Date().toISOString();
    let observationsCommitted = 0;

    // Commit each approved observation with strict provenance
    for (const field of approvedFields) {
      const finalValue = field.userEditedValue !== undefined && field.userEditedValue !== null
        ? field.userEditedValue
        : field.extractedValue;

      const rawUnit = field.userEditedUnit || field.unit;
      const finalUnit = sanitizeUnitForMeasurement(field.typeCode, rawUnit);

      const reviewState =
        field.userEditedValue !== undefined && field.userEditedValue !== null
          ? 'user_corrected'
          : 'user_reviewed';

      await MeasurementsService.recordObservation(
        userId,
        {
          typeCode: field.typeCode,
          value: finalValue,
          unit: finalUnit,
          observedAt,
          originType: 'ai_extraction',
          epistemicClass: field.epistemicClass,
          actor: 'user',
          confidenceScore: field.confidenceScore,
          sourceArtifactId: draft.mediaArtifactId || undefined,
          reviewState
        },
        correlationId
      );

      observationsCommitted++;
    }

    // Source Image Retention Control (Blueprint §13.2 Rule 10)
    let sourceImageDeleted = false;
    if (options.deleteSourceImage && draft.mediaArtifactId) {
      await withUserContext(userId, async (client) => {
        // Fetch path to delete physical file from disk
        const artRes = await client.query(
          `SELECT storage_path FROM media_artifacts WHERE id = $1 AND user_id = $2`,
          [draft.mediaArtifactId, userId]
        );

        if (artRes.rows.length > 0) {
          const filePath = artRes.rows[0].storage_path;
          try {
            if (fs.existsSync(filePath)) {
              fs.unlinkSync(filePath);
            }
          } catch {
            // Ignore file system unlink error
          }
        }

        // Mark artifact record as deleted (preserving metadata and ID for provenance lineage)
        await client.query(
          `UPDATE media_artifacts SET status = 'deleted', deleted_at = NOW() WHERE id = $1 AND user_id = $2`,
          [draft.mediaArtifactId, userId]
        );
        sourceImageDeleted = true;
      });
    } else if (draft.mediaArtifactId) {
      await withUserContext(userId, async (client) => {
        await client.query(
          `UPDATE media_artifacts SET status = 'retained' WHERE id = $1 AND user_id = $2`,
          [draft.mediaArtifactId, userId]
        );
      });
    }

    // Update draft status to committed
    const updatedDraft = await withUserContext(userId, async (client) => {
      const res = await client.query(
        `UPDATE extraction_drafts
         SET status = 'committed', committed_at = NOW(), updated_at = NOW()
         WHERE id = $1 AND user_id = $2
         RETURNING *`,
        [draftId, userId]
      );
      return mapExtractionDraftRow(res.rows[0]);
    });

    await AuditService.recordEvent({
      userId,
      actorType: 'user',
      action: 'extraction_draft_committed',
      entityType: 'extraction_draft',
      entityId: draftId,
      correlationId,
      status: 'success',
      metadata: {
        observationsCommitted,
        sourceArtifactId: draft.mediaArtifactId,
        sourceImageDeleted,
        imageKind: draft.imageKind
      }
    });

    return {
      draft: updatedDraft,
      observationsCommitted,
      sourceImageDeleted
    };
  }

  /**
   * Discards an uncommitted extraction draft without modifying health observations.
   */
  static async discardDraft(userId: string, draftId: string, correlationId: string): Promise<ExtractionDraft> {
    const draft = await this.getDraft(userId, draftId);
    if (!draft) {
      throw new Error(`Extraction draft not found: ${draftId}`);
    }

    if (draft.status === 'committed') {
      throw new Error(`Cannot discard already committed draft: ${draftId}`);
    }

    const updated = await withUserContext(userId, async (client) => {
      const res = await client.query(
        `UPDATE extraction_drafts SET status = 'discarded', updated_at = NOW() WHERE id = $1 AND user_id = $2 RETURNING *`,
        [draftId, userId]
      );
      return mapExtractionDraftRow(res.rows[0]);
    });

    await AuditService.recordEvent({
      userId,
      actorType: 'user',
      action: 'extraction_draft_discarded',
      entityType: 'extraction_draft',
      entityId: draftId,
      correlationId,
      status: 'success',
      metadata: { draftId }
    });

    return updated;
  }
}

function sanitizeUnitForMeasurement(typeCode: string, unit: string): string {
  if (unit === '%' || unit === 'pct' || unit === 'percent') return 'percent';
  if ((unit === 'level' || unit === 'score') && typeCode === 'visceral_fat') return 'score';
  return unit;
}
