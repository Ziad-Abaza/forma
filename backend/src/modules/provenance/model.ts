/**
 * Provenance Domain (ADR-009, §14)
 *
 * Requirements:
 * - Every important record MUST have provenance created in the same transaction.
 * - Epistemic Class (measured, calculated, estimated, asserted) is first-class.
 * - Provenance is immutable.
 * - Distinguishes origin type, actor, method/version, confidence, review state.
 */

export type OriginType =
  | 'manual_entry'
  | 'ai_extraction_image'
  | 'imported_document'
  | 'device_smart_scale'
  | 'wearable'
  | 'system_calculation'
  | 'user_correction'
  | 'ai_proposed_user_confirmed';

export type EpistemicClass =
  | 'measured'    // Instrument/device or direct reading
  | 'calculated'  // Deterministic derivation from formulas
  | 'estimated'   // Approximation with real uncertainty (e.g., visual estimate, projection)
  | 'asserted';   // User-stated without instrument

export type ReviewState =
  | 'unreviewed'
  | 'user_reviewed'
  | 'user_corrected';

export interface ProvenanceRecord {
  id: string;
  userId: string;
  originType: OriginType;
  epistemicClass: EpistemicClass;
  actor: {
    type: 'user' | 'system' | 'ai' | 'device';
    identifier?: string; // Model name, formula ID, or device serial
    version?: string;    // Prompt/model/formula version
  };
  confidenceScore: number; // 0.0 to 1.0 (1.0 for direct measurements/user assert)
  reviewState: ReviewState;
  sourceArtifactId?: string; // Image or document reference
  supersedesId?: string;     // Prior observation ID if this is a correction
  observedAt: string;        // ISO timestamp
  recordedAt: string;        // ISO timestamp
  reviewedAt?: string;       // ISO timestamp
}

export function createProvenanceRecord(params: {
  id: string;
  userId: string;
  originType: OriginType;
  epistemicClass: EpistemicClass;
  actor: ProvenanceRecord['actor'];
  confidenceScore?: number;
  reviewState?: ReviewState;
  sourceArtifactId?: string;
  supersedesId?: string;
  observedAt?: string;
}): ProvenanceRecord {
  const now = new Date().toISOString();
  return {
    id: params.id,
    userId: params.userId,
    originType: params.originType,
    epistemicClass: params.epistemicClass,
    actor: params.actor,
    confidenceScore: params.confidenceScore ?? 1.0,
    reviewState: params.reviewState ?? 'unreviewed',
    sourceArtifactId: params.sourceArtifactId,
    supersedesId: params.supersedesId,
    observedAt: params.observedAt ?? now,
    recordedAt: now,
  };
}
