import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { closePool, withUserContext } from '../core/database/index.js';
import { runMigrations } from '../core/database/migrate.js';
import { IdentityService } from '../modules/identity/service.js';
import { MeasurementsService } from '../modules/measurements/service.js';
import { PrivacyOrchestrator } from '../modules/privacy/index.js';

describe('Cross-User Double Isolation & RLS Security Tests', () => {
  let userAId: string;
  let userBId: string;
  let userAObservationId: string;

  beforeAll(async () => {
    process.env['NODE_ENV'] = 'test';
    await runMigrations();

    // Register User A
    const authA = await IdentityService.register(
      {
        email: `usera_${Date.now()}@forma.local`,
        password: 'Password123!',
        dateOfBirth: '1990-01-01',
        heightCm: 178,
        sexForCalculation: 'male',
        locale: 'en',
        numeralSystem: 'western',
        consents: { termsOfService: true, healthDataProcessing: true, aiThirdPartyProcessing: true }
      },
      'corr-isolation-reg-a'
    );
    userAId = authA.user.id;

    // Register User B
    const authB = await IdentityService.register(
      {
        email: `userb_${Date.now()}@forma.local`,
        password: 'Password123!',
        dateOfBirth: '1992-02-02',
        heightCm: 165,
        sexForCalculation: 'female',
        locale: 'ar',
        numeralSystem: 'eastern_arabic',
        consents: { termsOfService: true, healthDataProcessing: true, aiThirdPartyProcessing: true }
      },
      'corr-isolation-reg-b'
    );
    userBId = authB.user.id;

    // User A records an observation
    const obsA = await MeasurementsService.recordObservation(
      userAId,
      {
        typeCode: 'weight',
        value: 75.5,
        unit: 'kg',
        observedAt: new Date().toISOString(),
        timeZone: 'UTC',
        originType: 'manual_entry',
        epistemicClass: 'measured',
        actor: 'user',
        confidenceScore: 1.0,
        reviewState: 'user_reviewed'
      },
      'corr-obs-a'
    );
    userAObservationId = obsA.observation.id;

    // User B records an observation
    await MeasurementsService.recordObservation(
      userBId,
      {
        typeCode: 'weight',
        value: 60.0,
        unit: 'kg',
        observedAt: new Date().toISOString(),
        timeZone: 'UTC',
        originType: 'manual_entry',
        epistemicClass: 'measured',
        actor: 'user',
        confidenceScore: 1.0,
        reviewState: 'user_reviewed'
      },
      'corr-obs-b'
    );
  });

  afterAll(async () => {
    await closePool();
  });

  it('prohibits User B from reading User A observations via service query', async () => {
    const userBObservations = await MeasurementsService.queryObservations(userBId, { status: 'all' });
    expect(userBObservations.every(o => o.user_id === userBId)).toBe(true);
    expect(userBObservations.some(o => o.id === userAObservationId)).toBe(false);
  });

  it('enforces PostgreSQL RLS: direct raw SQL query by User B returns 0 rows of User A data', async () => {
    const rawQueryResult = await withUserContext(userBId, async (client) => {
      const res = await client.query('SELECT * FROM observations WHERE user_id = $1', [userAId]);
      return res.rows;
    });

    // RLS policy ensures row filter operates at DB level — zero rows visible
    expect(rawQueryResult.length).toBe(0);
  });

  it('enforces PostgreSQL RLS: User B cannot modify or void User A observation', async () => {
    await expect(
      MeasurementsService.voidObservation(
        userBId,
        {
          observationId: userAObservationId,
          reason: 'Malicious attempt by User B to void User A record'
        },
        'corr-malicious-void'
      )
    ).rejects.toThrow(/Observation not found/);
  });

  it('enforces PostgreSQL RLS: User B cannot access User A profile', async () => {
    const profile = await withUserContext(userBId, async (client) => {
      const res = await client.query('SELECT * FROM profiles WHERE user_id = $1', [userAId]);
      return res.rows;
    });
    expect(profile.length).toBe(0);
  });

  it('guarantees complete isolation during privacy export', async () => {
    const exportA = await PrivacyOrchestrator.exportAllUserData(userAId, 'corr-exp-a');
    const measData = (exportA.modules['measurements'] as any).observations as any[];
    expect(measData.every(o => o.user_id === userAId)).toBe(true);
    expect(measData.some(o => o.user_id === userBId)).toBe(false);
  });

  it('purging User A does not affect User B records', async () => {
    const purgeResult = await PrivacyOrchestrator.purgeUserAccount(userAId, 'corr-purge-a');
    expect(purgeResult.success).toBe(true);

    // Verify User B still exists and can query their observations
    const userBObservations = await MeasurementsService.queryObservations(userBId, { status: 'all' });
    expect(userBObservations.length).toBeGreaterThan(0);
    expect(userBObservations[0]?.user_id).toBe(userBId);
  });
});
