import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { closePool, withUserContext } from '../../core/database/index.js';
import { runMigrations } from '../../core/database/migrate.js';
import { IdentityService } from '../identity/service.js';
import { MeasurementsService } from './service.js';

describe('Measurements & Observations Integration Tests (Real PostgreSQL)', () => {
  let testUserId: string;

  beforeAll(async () => {
    process.env['NODE_ENV'] = 'test';
    await runMigrations();

    // Register a test user for observation testing
    const email = `meas_test_${Date.now()}@forma.local`;
    const auth = await IdentityService.register(
      {
        email,
        password: 'Password123!',
        dateOfBirth: '1992-05-20',
        heightCm: 175,
        sexForCalculation: 'female',
        locale: 'en',
        numeralSystem: 'western',
        consents: {
          termsOfService: true,
          healthDataProcessing: true,
          aiThirdPartyProcessing: true
        }
      },
      'corr-meas-init'
    );
    testUserId = auth.user.id;
  });

  afterAll(async () => {
    await closePool();
  });

  it('records an observation with canonical normalization and mandatory provenance', async () => {
    const inputLb = 165.5;
    const res = await MeasurementsService.recordObservation(
      testUserId,
      {
        typeCode: 'weight',
        value: inputLb,
        unit: 'lb',
        observedAt: new Date().toISOString(),
        timeZone: 'America/New_York',
        originType: 'manual_entry',
        epistemicClass: 'measured',
        actor: 'user',
        confidenceScore: 1.0,
        reviewState: 'user_reviewed'
      },
      'corr-meas-create'
    );

    expect(res.observation.id).toBeDefined();
    expect(res.observation.canonical_unit).toBe('kg');
    expect(res.observation.original_value).toBe(inputLb);
    expect(res.observation.original_unit).toBe('lb');
    expect(res.observation.input_precision).toBe(1);
    expect(res.observation.status).toBe('active');

    // Verify provenance
    expect(res.provenance.id).toBe(res.observation.provenance_id);
    expect(res.provenance.origin_type).toBe('manual_entry');
    expect(res.provenance.epistemic_class).toBe('measured');
    expect(res.provenance.confidence_score).toBe(1.0);
  });

  it('enforces database trigger: raw UPDATE of values is rejected by PostgreSQL', async () => {
    const res = await MeasurementsService.recordObservation(
      testUserId,
      {
        typeCode: 'waist_circumference',
        value: 85.0,
        unit: 'cm',
        observedAt: new Date().toISOString(),
        timeZone: 'UTC',
        originType: 'manual_entry',
        epistemicClass: 'measured',
        actor: 'user',
        confidenceScore: 1.0,
        reviewState: 'user_reviewed'
      },
      'corr-meas-immutability-check'
    );

    // Attempt direct SQL update on immutable canonical value
    await expect(
      withUserContext(testUserId, async (client) => {
        await client.query(
          'UPDATE observations SET canonical_value = 999.0 WHERE id = $1',
          [res.observation.id]
        );
      })
    ).rejects.toThrow(/Observations are immutable facts/);
  });

  it('enforces database trigger: raw DELETE of observations is rejected by PostgreSQL', async () => {
    const res = await MeasurementsService.recordObservation(
      testUserId,
      {
        typeCode: 'body_fat_percentage',
        value: 18.5,
        unit: 'percent',
        observedAt: new Date().toISOString(),
        timeZone: 'UTC',
        originType: 'manual_entry',
        epistemicClass: 'measured',
        actor: 'user',
        confidenceScore: 1.0,
        reviewState: 'user_reviewed'
      },
      'corr-meas-delete-check'
    );

    // Attempt direct SQL deletion
    await expect(
      withUserContext(testUserId, async (client) => {
        await client.query('DELETE FROM observations WHERE id = $1', [res.observation.id]);
      })
    ).rejects.toThrow(/Hard deletion of observations is prohibited/);
  });

  it('corrects observation via supersession, preserving the original fact', async () => {
    const original = await MeasurementsService.recordObservation(
      testUserId,
      {
        typeCode: 'weight',
        value: 80.0,
        unit: 'kg',
        observedAt: '2026-03-01T08:00:00Z',
        timeZone: 'UTC',
        originType: 'manual_entry',
        epistemicClass: 'measured',
        actor: 'user',
        confidenceScore: 1.0,
        reviewState: 'user_reviewed'
      },
      'corr-supersede-orig'
    );

    const superseded = await MeasurementsService.supersedeObservation(
      testUserId,
      {
        previousObservationId: original.observation.id,
        newValue: 80.5,
        newUnit: 'kg',
        correctionReason: 'Typo during manual weigh-in entry'
      },
      'corr-supersede-action'
    );

    expect(superseded.newObservation.canonical_value).toBe(80.5);
    expect(superseded.newObservation.supersedes).toBe(original.observation.id);

    // Verify original observation is marked superseded and points forward
    const queryOld = await MeasurementsService.queryObservations(testUserId, {
      typeCode: 'weight',
      status: 'all',
      limit: 10
    });

    const oldFound = queryOld.find(o => o.id === original.observation.id);
    expect(oldFound?.status).toBe('superseded');
    expect(oldFound?.superseded_by).toBe(superseded.newObservation.id);
  });

  it('voids an observation without deleting it from the database', async () => {
    const toVoid = await MeasurementsService.recordObservation(
      testUserId,
      {
        typeCode: 'chest_circumference',
        value: 102.0,
        unit: 'cm',
        observedAt: new Date().toISOString(),
        timeZone: 'UTC',
        originType: 'manual_entry',
        epistemicClass: 'measured',
        actor: 'user',
        confidenceScore: 1.0,
        reviewState: 'user_reviewed'
      },
      'corr-void-setup'
    );

    const voided = await MeasurementsService.voidObservation(
      testUserId,
      {
        observationId: toVoid.observation.id,
        reason: 'Duplicate entry accidentally entered twice'
      },
      'corr-void-action'
    );

    expect(voided.status).toBe('voided');
    expect(voided.void_reason).toBe('Duplicate entry accidentally entered twice');

    // Confirm that query with status: 'active' filters it out
    const activeList = await MeasurementsService.queryObservations(testUserId, {
      typeCode: 'chest_circumference',
      status: 'active'
    });
    expect(activeList.some(o => o.id === toVoid.observation.id)).toBe(false);

    // Confirm that query with status: 'voided' or 'all' retains the record
    const allList = await MeasurementsService.queryObservations(testUserId, {
      typeCode: 'chest_circumference',
      status: 'all'
    });
    expect(allList.some(o => o.id === toVoid.observation.id)).toBe(true);
  });

  it('rejects unpermitted units for measurement types', async () => {
    await expect(
      MeasurementsService.recordObservation(
        testUserId,
        {
          typeCode: 'body_fat_percentage',
          value: 15,
          unit: 'kg', // Invalid unit for body fat %
          observedAt: new Date().toISOString(),
          timeZone: 'UTC',
          originType: 'manual_entry',
          epistemicClass: 'measured',
          actor: 'user',
          confidenceScore: 1.0,
          reviewState: 'user_reviewed'
        },
        'corr-invalid-unit'
      )
    ).rejects.toThrow(/not permitted for measurement/);
  });
});
