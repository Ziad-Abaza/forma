/**
 * Measurements & Observations Domain (ADR-009, §7.1, §7.2, §7.5)
 *
 * Rules:
 * - Append-only facts: Observations are never mutated or silently deleted.
 * - Deletion semantics: Voiding an observation sets status to 'voided'.
 * - Correction semantics: Creates a new observation pointing to supersedesId.
 * - Normalized canonical value + preserved original value, unit & precision.
 * - Every observation requires a provenance record.
 */

import { ProvenanceRecord, createProvenanceRecord, OriginType, EpistemicClass } from '../provenance/model.js';
import { UnitRegistry } from '../../core/units.js';
import { MeasurementCatalog } from './catalog.js';

export type ObservationStatus = 'active' | 'superseded' | 'voided';

export interface Observation {
  id: string;
  userId: string;
  typeCode: string;
  canonicalValue: number;
  canonicalUnit: string;
  originalValue: number;
  originalUnit: string;
  inputPrecision: number;
  registryVersion: string;
  observedAt: string;        // UTC ISO instant
  recordedAt: string;        // UTC ISO instant
  timeZoneContext: string;   // e.g. "Africa/Cairo", "America/New_York"
  sessionId?: string;        // Optional grouping for co-measurements
  status: ObservationStatus;
  supersedesId?: string;     // If this observation replaces an earlier one
  supersededById?: string;   // Set when replaced by a newer observation
  provenanceId: string;
  provenance?: ProvenanceRecord;
  qualityFlags: string[];    // e.g., ['unit-inferred', 'outlier-warning']
}

export interface CreateObservationParams {
  id: string;
  userId: string;
  typeCode: string;
  value: number;
  unit: string;
  observedAt?: string;
  timeZoneContext?: string;
  sessionId?: string;
  originType?: OriginType;
  epistemicClass?: EpistemicClass;
  actor?: ProvenanceRecord['actor'];
  confidenceScore?: number;
  sourceArtifactId?: string;
  supersedesId?: string;
}

export class ObservationService {
  /**
   * Create an observation adhering to canonical normalization and mandatory provenance.
   */
  static createObservation(params: CreateObservationParams): {
    observation: Observation;
    provenance: ProvenanceRecord;
    warnings: string[];
  } {
    // 1. Verify measurement type catalog
    const typeDef = MeasurementCatalog.get(params.typeCode);

    // 2. Validate and normalize units
    const normalized = UnitRegistry.normalize(params.value, params.unit);
    if (normalized.canonicalUnit !== typeDef.canonicalUnit) {
      throw new Error(
        `Unit '${params.unit}' normalizes to '${normalized.canonicalUnit}', expected '${typeDef.canonicalUnit}' for ${typeDef.code}`
      );
    }

    // 3. Check biological plausibility
    const plausibility = MeasurementCatalog.validatePlausibility(params.typeCode, normalized.canonicalValue);
    if (!plausibility.isValid) {
      throw new Error(`Data validation error: ${plausibility.reason}`);
    }

    const qualityFlags: string[] = [];
    const warnings: string[] = [];
    if (plausibility.isWarning && plausibility.reason) {
      qualityFlags.push('plausibility-warning');
      warnings.push(plausibility.reason);
    }

    const now = new Date().toISOString();
    const observedAt = params.observedAt ?? now;
    const provenanceId = `prov_${params.id}`;

    // 4. Construct immutable Provenance record
    const provenance = createProvenanceRecord({
      id: provenanceId,
      userId: params.userId,
      originType: params.originType ?? 'manual_entry',
      epistemicClass: params.epistemicClass ?? 'asserted',
      actor: params.actor ?? { type: 'user' },
      confidenceScore: params.confidenceScore ?? 1.0,
      sourceArtifactId: params.sourceArtifactId,
      supersedesId: params.supersedesId,
      observedAt,
    });

    // 5. Construct Observation record
    const observation: Observation = {
      id: params.id,
      userId: params.userId,
      typeCode: typeDef.code,
      canonicalValue: normalized.canonicalValue,
      canonicalUnit: normalized.canonicalUnit,
      originalValue: normalized.originalValue,
      originalUnit: normalized.originalUnit,
      inputPrecision: normalized.inputPrecision,
      registryVersion: normalized.registryVersion,
      observedAt,
      recordedAt: now,
      timeZoneContext: params.timeZoneContext ?? 'UTC',
      sessionId: params.sessionId,
      status: 'active',
      supersedesId: params.supersedesId,
      provenanceId,
      provenance,
      qualityFlags,
    };

    return { observation, provenance, warnings };
  }

  /**
   * Supercede an existing observation with a corrected one (ADR-009, §7.1).
   */
  static supersedeObservation(
    existing: Observation,
    newParams: Omit<CreateObservationParams, 'supersedesId'>
  ): {
    updatedOld: Observation;
    newObservation: Observation;
    newProvenance: ProvenanceRecord;
    warnings: string[];
  } {
    if (existing.status !== 'active') {
      throw new Error(`Cannot supersede observation with status '${existing.status}'`);
    }

    const { observation: newObs, provenance: newProv, warnings } = this.createObservation({
      ...newParams,
      supersedesId: existing.id,
      originType: newParams.originType ?? 'user_correction',
    });

    const updatedOld: Observation = {
      ...existing,
      status: 'superseded',
      supersededById: newObs.id,
    };

    return {
      updatedOld,
      newObservation: newObs,
      newProvenance: newProv,
      warnings,
    };
  }

  /**
   * Void an observation (Soft-delete / lineage integrity preservation).
   */
  static voidObservation(existing: Observation, reason?: string): Observation {
    if (existing.status !== 'active') {
      throw new Error(`Cannot void observation with status '${existing.status}'`);
    }
    return {
      ...existing,
      status: 'voided',
      qualityFlags: reason ? [...existing.qualityFlags, `voided: ${reason}`] : [...existing.qualityFlags, 'voided'],
    };
  }
}
