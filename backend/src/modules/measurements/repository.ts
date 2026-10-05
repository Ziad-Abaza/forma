import type { PoolClient } from 'pg';
import type { EpistemicClass, OriginType, QueryObservationsFilter } from './contracts.js';

export interface MeasurementTypeRecord {
  code: string;
  category: string;
  dimension: string;
  canonical_unit: string;
  allowed_units: string[];
  min_plausible: number;
  max_plausible: number;
  laterality: string;
  is_user_enterable: boolean;
  is_derived: boolean;
}

export interface ProvenanceRecord {
  id: string;
  user_id: string;
  origin_type: OriginType;
  epistemic_class: EpistemicClass;
  actor: string;
  method_version: string;
  confidence_score: number;
  source_artifact_id: string | null;
  review_state: string;
  observed_at: Date;
  recorded_at: Date;
  reviewed_at: Date | null;
}

export interface ObservationRecord {
  id: string;
  user_id: string;
  type_code: string;
  canonical_value: number;
  canonical_unit: string;
  original_value: number;
  original_unit: string;
  input_precision: number;
  observed_at: Date;
  recorded_at: Date;
  time_zone: string;
  provenance_id: string;
  quality_flags: string[];
  status: 'active' | 'superseded' | 'voided';
  superseded_by: string | null;
  supersedes: string | null;
  voided_at: Date | null;
  void_reason: string | null;
}

export class MeasurementsRepository {
  static async getMeasurementType(client: PoolClient, code: string): Promise<MeasurementTypeRecord | null> {
    const res = await client.query('SELECT * FROM measurement_types WHERE code = $1', [code]);
    if (!res.rows[0]) return null;
    const r = res.rows[0];
    return {
      code: r.code,
      category: r.category,
      dimension: r.dimension,
      canonical_unit: r.canonical_unit,
      allowed_units: r.allowed_units,
      min_plausible: Number(r.min_plausible),
      max_plausible: Number(r.max_plausible),
      laterality: r.laterality,
      is_user_enterable: r.is_user_enterable,
      is_derived: r.is_derived
    };
  }

  static async listMeasurementTypes(client: PoolClient): Promise<MeasurementTypeRecord[]> {
    const res = await client.query('SELECT * FROM measurement_types ORDER BY category, code');
    return res.rows.map(r => ({
      code: r.code,
      category: r.category,
      dimension: r.dimension,
      canonical_unit: r.canonical_unit,
      allowed_units: r.allowed_units,
      min_plausible: Number(r.min_plausible),
      max_plausible: Number(r.max_plausible),
      laterality: r.laterality,
      is_user_enterable: r.is_user_enterable,
      is_derived: r.is_derived
    }));
  }

  static async createProvenance(
    client: PoolClient,
    data: {
      userId: string;
      originType: OriginType;
      epistemicClass: EpistemicClass;
      actor: string;
      methodVersion: string;
      confidenceScore: number;
      sourceArtifactId?: string | undefined;
      reviewState: string;
      observedAt: string | Date;
    }
  ): Promise<ProvenanceRecord> {
    const res = await client.query(
      `INSERT INTO provenance_records (
        user_id, origin_type, epistemic_class, actor, method_version,
        confidence_score, source_artifact_id, review_state, observed_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      RETURNING *`,
      [
        data.userId,
        data.originType,
        data.epistemicClass,
        data.actor,
        data.methodVersion,
        data.confidenceScore,
        data.sourceArtifactId || null,
        data.reviewState,
        data.observedAt
      ]
    );
    const r = res.rows[0];
    return {
      id: r.id,
      user_id: r.user_id,
      origin_type: r.origin_type,
      epistemic_class: r.epistemic_class,
      actor: r.actor,
      method_version: r.method_version,
      confidence_score: Number(r.confidence_score),
      source_artifact_id: r.source_artifact_id,
      review_state: r.review_state,
      observed_at: r.observed_at,
      recorded_at: r.recorded_at,
      reviewed_at: r.reviewed_at
    };
  }

  static async createObservation(
    client: PoolClient,
    data: {
      userId: string;
      typeCode: string;
      canonicalValue: number;
      canonicalUnit: string;
      originalValue: number;
      originalUnit: string;
      inputPrecision: number;
      observedAt: string | Date;
      timeZone: string;
      provenanceId: string;
      qualityFlags?: string[];
      supersedes?: string;
    }
  ): Promise<ObservationRecord> {
    const res = await client.query(
      `INSERT INTO observations (
        user_id, type_code, canonical_value, canonical_unit, original_value, original_unit,
        input_precision, observed_at, time_zone, provenance_id, quality_flags, supersedes
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
      RETURNING *`,
      [
        data.userId,
        data.typeCode,
        data.canonicalValue,
        data.canonicalUnit,
        data.originalValue,
        data.originalUnit,
        data.inputPrecision,
        data.observedAt,
        data.timeZone,
        data.provenanceId,
        data.qualityFlags || [],
        data.supersedes || null
      ]
    );
    return this.mapObservation(res.rows[0]);
  }

  static async getObservationById(client: PoolClient, id: string): Promise<ObservationRecord | null> {
    const res = await client.query('SELECT * FROM observations WHERE id = $1', [id]);
    if (!res.rows[0]) return null;
    return this.mapObservation(res.rows[0]);
  }

  static async markSuperseded(client: PoolClient, oldId: string, newId: string): Promise<void> {
    await client.query(
      "UPDATE observations SET status = 'superseded', superseded_by = $1 WHERE id = $2",
      [newId, oldId]
    );
  }

  static async markVoided(client: PoolClient, id: string, reason: string): Promise<void> {
    await client.query(
      "UPDATE observations SET status = 'voided', voided_at = NOW(), void_reason = $1 WHERE id = $2",
      [reason, id]
    );
  }

  static async queryObservations(
    client: PoolClient,
    userId: string,
    filter: QueryObservationsFilter
  ): Promise<ObservationRecord[]> {
    const conditions = ['user_id = $1'];
    const params: unknown[] = [userId];
    let paramIdx = 2;

    if (filter.typeCode) {
      conditions.push(`type_code = $${paramIdx++}`);
      params.push(filter.typeCode);
    }

    if (filter.status !== 'all') {
      conditions.push(`status = $${paramIdx++}`);
      params.push(filter.status);
    }

    if (filter.fromDate) {
      conditions.push(`observed_at >= $${paramIdx++}`);
      params.push(filter.fromDate);
    }

    if (filter.toDate) {
      conditions.push(`observed_at <= $${paramIdx++}`);
      params.push(filter.toDate);
    }

    params.push(filter.limit || 50);
    const sql = `
      SELECT * FROM observations
      WHERE ${conditions.join(' AND ')}
      ORDER BY observed_at DESC
      LIMIT $${paramIdx}
    `;

    const res = await client.query(sql, params);
    return res.rows.map(r => this.mapObservation(r));
  }

  static async getProvenanceById(client: PoolClient, id: string): Promise<ProvenanceRecord | null> {
    const res = await client.query('SELECT * FROM provenance_records WHERE id = $1', [id]);
    if (!res.rows[0]) return null;
    const r = res.rows[0];
    return {
      id: r.id,
      user_id: r.user_id,
      origin_type: r.origin_type,
      epistemic_class: r.epistemic_class,
      actor: r.actor,
      method_version: r.method_version,
      confidence_score: Number(r.confidence_score),
      source_artifact_id: r.source_artifact_id,
      review_state: r.review_state,
      observed_at: r.observed_at,
      recorded_at: r.recorded_at,
      reviewed_at: r.reviewed_at
    };
  }

  private static mapObservation(r: any): ObservationRecord {
    return {
      id: r.id,
      user_id: r.user_id,
      type_code: r.type_code,
      canonical_value: Number(r.canonical_value),
      canonical_unit: r.canonical_unit,
      original_value: Number(r.original_value),
      original_unit: r.original_unit,
      input_precision: r.input_precision,
      observed_at: r.observed_at,
      recorded_at: r.recorded_at,
      time_zone: r.time_zone,
      provenance_id: r.provenance_id,
      quality_flags: r.quality_flags,
      status: r.status,
      superseded_by: r.superseded_by,
      supersedes: r.supersedes,
      voided_at: r.voided_at,
      void_reason: r.void_reason
    };
  }
}
