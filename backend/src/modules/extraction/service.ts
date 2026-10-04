/**
 * Multimodal & Image Extraction Domain (ADR-011, §13)
 *
 * Rules:
 * - AI extraction NEVER auto-saves. Review is mandatory.
 * - Extraction Draft: structured output against Measurement Type Catalog.
 * - Validation: unit normalization, plausibility ranges, cross-field consistency.
 * - Per-field confidence scoring (high-confidence vs low-confidence flagging).
 * - Commit: creates a Measurement Session with image provenance.
 * - Private storage, user-controlled retention (delete after commit option).
 */

import { MeasurementCatalog } from '../measurements/catalog.js';
import { UnitRegistry } from '../../core/units.js';
import { Observation, ObservationService } from '../measurements/model.js';
import { ProvenanceRecord } from '../provenance/model.js';

export interface ExtractedFieldDraft {
  typeCode: string;
  rawValue: number;
  rawUnit: string;
  canonicalValue: number;
  canonicalUnit: string;
  confidence: number; // 0.0 to 1.0
  isApproved: boolean;
  editedValue?: number;
  editedUnit?: string;
  qualityFlags: string[];
}

export interface ExtractionDraft {
  draftId: string;
  userId: string;
  sourceArtifactId: string;
  sourceType: 'body_composition_report' | 'smart_scale_display' | 'tape_sheet';
  status: 'draft' | 'committed' | 'discarded';
  fields: ExtractedFieldDraft[];
  createdAt: string;
}

export class ExtractionService {
  /**
   * Parse extracted raw values into a validated Extraction Draft.
   */
  static createDraft(params: {
    userId: string;
    sourceArtifactId: string;
    sourceType: ExtractionDraft['sourceType'];
    rawExtractedData: Array<{
      typeCode: string;
      value: number;
      unit: string;
      confidence: number;
    }>;
  }): ExtractionDraft {
    const draftId = `draft_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const fields: ExtractedFieldDraft[] = [];

    for (const item of params.rawExtractedData) {
      // 1. Verify against catalog
      const typeDef = MeasurementCatalog.get(item.typeCode);

      // 2. Normalize canonical units
      const normalized = UnitRegistry.normalize(item.value, item.unit);

      // 3. Plausibility check
      const plausibility = MeasurementCatalog.validatePlausibility(typeDef.code, normalized.canonicalValue);
      const qualityFlags: string[] = [];

      if (!plausibility.isValid) {
        qualityFlags.push('biologically-implausible');
      } else if (plausibility.isWarning) {
        qualityFlags.push('outlier-warning');
      }

      if (item.confidence < 0.8) {
        qualityFlags.push('low-confidence-attention-required');
      }

      fields.push({
        typeCode: typeDef.code,
        rawValue: item.value,
        rawUnit: item.unit,
        canonicalValue: normalized.canonicalValue,
        canonicalUnit: normalized.canonicalUnit,
        confidence: item.confidence,
        isApproved: item.confidence >= 0.8 && plausibility.isValid, // Auto-select only if high confidence
        qualityFlags,
      });
    }

    return {
      draftId,
      userId: params.userId,
      sourceArtifactId: params.sourceArtifactId,
      sourceType: params.sourceType,
      status: 'draft',
      fields,
      createdAt: new Date().toISOString(),
    };
  }

  /**
   * Commit approved draft fields into a Measurement Session with provenance (ADR-011).
   */
  static commitDraft(
    draft: ExtractionDraft,
    userId: string
  ): {
    observations: Observation[];
    provenances: ProvenanceRecord[];
    sessionId: string;
  } {
    if (draft.userId !== userId) {
      throw new Error('Unauthorized draft commit attempt');
    }

    if (draft.status !== 'draft') {
      throw new Error(`Draft status is '${draft.status}', cannot commit`);
    }

    const approvedFields = draft.fields.filter((f) => f.isApproved);
    if (approvedFields.length === 0) {
      throw new Error('No fields approved for commit');
    }

    const sessionId = `session_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const observations: Observation[] = [];
    const provenances: ProvenanceRecord[] = [];

    for (const field of approvedFields) {
      const val = field.editedValue ?? field.rawValue;
      const unit = field.editedUnit ?? field.rawUnit;

      const res = ObservationService.createObservation({
        id: `obs_ext_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
        userId,
        typeCode: field.typeCode,
        value: val,
        unit,
        sessionId,
        originType: 'ai_extraction_image',
        epistemicClass: 'measured',
        confidenceScore: field.confidence,
        sourceArtifactId: draft.sourceArtifactId,
        actor: { type: 'ai', identifier: 'vision-extraction', version: '1.0.0' },
      });

      observations.push(res.observation);
      provenances.push(res.provenance);
    }

    draft.status = 'committed';

    return {
      observations,
      provenances,
      sessionId,
    };
  }
}
