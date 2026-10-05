import { withUserContext } from '../../core/database/index.js';
import { normalizeToCanonical } from '../../core/units/index.js';
import { AuditService } from '../audit/index.js';
import {
  MeasurementsRepository,
  type ObservationRecord,
  type ProvenanceRecord,
  type MeasurementTypeRecord
} from './repository.js';
import type {
  CreateObservationRequest,
  SupersedeObservationRequest,
  VoidObservationRequest,
  QueryObservationsFilter
} from './contracts.js';

export interface ObservationWithProvenance {
  observation: ObservationRecord;
  provenance: ProvenanceRecord;
}

export class MeasurementsService {
  /**
   * Records a health observation with mandatory provenance in the same transaction.
   * Enforces canonical normalization, allowed unit verification, and plausibility boundaries.
   */
  static async recordObservation(
    userId: string,
    req: CreateObservationRequest,
    correlationId: string
  ): Promise<ObservationWithProvenance> {
    return await withUserContext(userId, async (client) => {
      const type = await MeasurementsRepository.getMeasurementType(client, req.typeCode);
      if (!type) {
        throw new Error(`Unknown measurement type code: ${req.typeCode}`);
      }

      if (req.originType === 'manual_entry' && !type.is_user_enterable) {
        throw new Error(`Measurement type ${req.typeCode} cannot be entered manually (derived only).`);
      }

      if (!type.allowed_units.includes(req.unit)) {
        throw new Error(
          `Unit '${req.unit}' is not permitted for measurement '${req.typeCode}'. Permitted units: ${type.allowed_units.join(', ')}`
        );
      }

      // Convert to canonical unit
      const normalized = normalizeToCanonical(req.value, req.unit);

      // Plausibility boundary checks
      const qualityFlags: string[] = [];
      if (
        normalized.canonicalValue < type.min_plausible ||
        normalized.canonicalValue > type.max_plausible
      ) {
        qualityFlags.push('outlier');
      }

      // Mandatory Provenance Creation
      const provenance = await MeasurementsRepository.createProvenance(client, {
        userId,
        originType: req.originType,
        epistemicClass: req.epistemicClass,
        actor: req.actor,
        methodVersion: '1.0.0',
        confidenceScore: req.confidenceScore,
        sourceArtifactId: req.sourceArtifactId,
        reviewState: req.reviewState,
        observedAt: req.observedAt
      });

      // Observation Creation pointing to the provenance record
      const observation = await MeasurementsRepository.createObservation(client, {
        userId,
        typeCode: req.typeCode,
        canonicalValue: normalized.canonicalValue,
        canonicalUnit: normalized.canonicalUnit,
        originalValue: normalized.originalValue,
        originalUnit: normalized.originalUnit,
        inputPrecision: normalized.inputPrecision,
        observedAt: req.observedAt,
        timeZone: req.timeZone,
        provenanceId: provenance.id,
        qualityFlags
      });

      await AuditService.recordEvent(
        {
          userId,
          actorType: 'user',
          action: 'observation_recorded',
          entityType: 'observation',
          entityId: observation.id,
          correlationId,
          status: 'success',
          metadata: {
            typeCode: req.typeCode,
            epistemicClass: req.epistemicClass,
            originType: req.originType,
            qualityFlags
          }
        },
        client
      );

      return { observation, provenance };
    });
  }

  /**
   * Corrects an existing observation via supersession, preserving the original fact and history.
   */
  static async supersedeObservation(
    userId: string,
    req: SupersedeObservationRequest,
    correlationId: string
  ): Promise<{ newObservation: ObservationRecord; previousObservation: ObservationRecord }> {
    return await withUserContext(userId, async (client) => {
      const prev = await MeasurementsRepository.getObservationById(client, req.previousObservationId);
      if (!prev) {
        throw new Error('Previous observation not found');
      }

      if (prev.status !== 'active') {
        throw new Error(`Cannot supersede observation with status '${prev.status}'`);
      }

      const type = await MeasurementsRepository.getMeasurementType(client, prev.type_code);
      if (!type) {
        throw new Error(`Unknown measurement type: ${prev.type_code}`);
      }

      if (!type.allowed_units.includes(req.newUnit)) {
        throw new Error(`Unit '${req.newUnit}' is not permitted for '${prev.type_code}'`);
      }

      const normalized = normalizeToCanonical(req.newValue, req.newUnit);
      const observedAt = req.observedAt || prev.observed_at.toISOString();

      // Create new provenance record explicitly marked as 'user_correction'
      const provenance = await MeasurementsRepository.createProvenance(client, {
        userId,
        originType: 'user_correction',
        epistemicClass: 'measured',
        actor: 'user',
        methodVersion: '1.0.0',
        confidenceScore: 1.0,
        reviewState: 'user_corrected',
        observedAt
      });

      // Create the new observation referencing the superseded observation
      const newObs = await MeasurementsRepository.createObservation(client, {
        userId,
        typeCode: prev.type_code,
        canonicalValue: normalized.canonicalValue,
        canonicalUnit: normalized.canonicalUnit,
        originalValue: normalized.originalValue,
        originalUnit: normalized.originalUnit,
        inputPrecision: normalized.inputPrecision,
        observedAt,
        timeZone: prev.time_zone,
        provenanceId: provenance.id,
        supersedes: prev.id
      });

      // Mark previous observation as superseded
      await MeasurementsRepository.markSuperseded(client, prev.id, newObs.id);

      await AuditService.recordEvent(
        {
          userId,
          actorType: 'user',
          action: 'observation_superseded',
          entityType: 'observation',
          entityId: newObs.id,
          correlationId,
          status: 'success',
          metadata: {
            supersededObservationId: prev.id,
            reason: req.correctionReason
          }
        },
        client
      );

      return {
        newObservation: newObs,
        previousObservation: { ...prev, status: 'superseded', superseded_by: newObs.id }
      };
    });
  }

  /**
   * Voids an observation. Does NOT physically delete the database row.
   */
  static async voidObservation(
    userId: string,
    req: VoidObservationRequest,
    correlationId: string
  ): Promise<ObservationRecord> {
    return await withUserContext(userId, async (client) => {
      const obs = await MeasurementsRepository.getObservationById(client, req.observationId);
      if (!obs) {
        throw new Error('Observation not found');
      }

      if (obs.status !== 'active') {
        throw new Error(`Cannot void observation with status '${obs.status}'`);
      }

      await MeasurementsRepository.markVoided(client, req.observationId, req.reason);

      await AuditService.recordEvent(
        {
          userId,
          actorType: 'user',
          action: 'observation_voided',
          entityType: 'observation',
          entityId: obs.id,
          correlationId,
          status: 'success',
          metadata: { reason: req.reason }
        },
        client
      );

      return {
        ...obs,
        status: 'voided',
        voided_at: new Date(),
        void_reason: req.reason
      };
    });
  }

  /**
   * Lists catalog types.
   */
  static async listTypes(): Promise<MeasurementTypeRecord[]> {
    return await withUserContext('00000000-0000-0000-0000-000000000000', async (client) => {
      return await MeasurementsRepository.listMeasurementTypes(client);
    });
  }

  /**
   * Queries user observations subject to RLS.
   */
  static async queryObservations(
    userId: string,
    filter: QueryObservationsFilter
  ): Promise<ObservationRecord[]> {
    return await withUserContext(userId, async (client) => {
      return await MeasurementsRepository.queryObservations(client, userId, filter);
    });
  }

  /**
   * Retrieves provenance for an observation.
   */
  static async getProvenance(userId: string, provenanceId: string): Promise<ProvenanceRecord | null> {
    return await withUserContext(userId, async (client) => {
      return await MeasurementsRepository.getProvenanceById(client, provenanceId);
    });
  }
}
