import { describe, it, expect } from 'vitest';
import { ObservationService } from './model.js';
import { MeasurementCatalog } from './catalog.js';

describe('ObservationService & Measurement Domain (ADR-009, §7.1, §7.5)', () => {
  it('creates an observation with canonical normalization and mandatory provenance', () => {
    const res = ObservationService.createObservation({
      id: 'obs_1',
      userId: 'user_123',
      typeCode: 'weight',
      value: 180.5,
      unit: 'lb',
      originType: 'manual_entry',
      epistemicClass: 'measured',
    });

    expect(res.observation.id).toBe('obs_1');
    expect(res.observation.userId).toBe('user_123');
    expect(res.observation.typeCode).toBe('weight');
    expect(res.observation.canonicalUnit).toBe('kg');
    expect(res.observation.canonicalValue).toBeCloseTo(81.8734, 3);
    expect(res.observation.originalValue).toBe(180.5);
    expect(res.observation.originalUnit).toBe('lb');
    expect(res.observation.inputPrecision).toBe(1);
    expect(res.observation.status).toBe('active');

    // Provenance validation
    expect(res.provenance.id).toBe('prov_obs_1');
    expect(res.provenance.originType).toBe('manual_entry');
    expect(res.provenance.epistemicClass).toBe('measured');
    expect(res.provenance.confidenceScore).toBe(1.0);
    expect(res.provenance.actor.type).toBe('user');
  });

  it('rejects biologically impossible values', () => {
    expect(() =>
      ObservationService.createObservation({
        id: 'obs_bad',
        userId: 'user_123',
        typeCode: 'weight',
        value: 12.0, // Under plausible minimum 20 kg
        unit: 'kg',
      })
    ).toThrowError(/outside biologically plausible limits/);
  });

  it('flags plausible warning values without blocking creation', () => {
    const res = ObservationService.createObservation({
      id: 'obs_warn',
      userId: 'user_123',
      typeCode: 'weight',
      value: 280.0, // Plausible (< 400 kg) but warning (> 250 kg)
      unit: 'kg',
    });

    expect(res.observation.status).toBe('active');
    expect(res.warnings.length).toBeGreaterThan(0);
    expect(res.observation.qualityFlags).toContain('plausibility-warning');
  });

  it('supersedes an observation without mutating prior history', () => {
    const initial = ObservationService.createObservation({
      id: 'obs_orig',
      userId: 'user_123',
      typeCode: 'weight',
      value: 80.0,
      unit: 'kg',
    });

    const correction = ObservationService.supersedeObservation(initial.observation, {
      id: 'obs_corr',
      userId: 'user_123',
      typeCode: 'weight',
      value: 80.5,
      unit: 'kg',
    });

    expect(correction.updatedOld.status).toBe('superseded');
    expect(correction.updatedOld.supersededById).toBe('obs_corr');

    expect(correction.newObservation.id).toBe('obs_corr');
    expect(correction.newObservation.supersedesId).toBe('obs_orig');
    expect(correction.newObservation.status).toBe('active');
    expect(correction.newProvenance.originType).toBe('user_correction');
  });

  it('correctly voids an observation preserving auditability', () => {
    const initial = ObservationService.createObservation({
      id: 'obs_void_target',
      userId: 'user_123',
      typeCode: 'waist_circ',
      value: 85.0,
      unit: 'cm',
    });

    const voided = ObservationService.voidObservation(initial.observation, 'user mistyped value');
    expect(voided.status).toBe('voided');
    expect(voided.qualityFlags).toContain('voided: user mistyped value');
  });
});
