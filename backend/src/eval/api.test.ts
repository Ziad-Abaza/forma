import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import type { FastifyInstance } from 'fastify';
import { buildApp } from '../app.js';
import { closePool } from '../core/database/index.js';
import { runMigrations } from '../core/database/migrate.js';

describe('Fastify HTTP API End-to-End Tests', () => {
  let app: FastifyInstance;
  let userAToken: string;
  let userBToken: string;
  let userAId: string;
  let observationAId: string;

  beforeAll(async () => {
    process.env['NODE_ENV'] = 'test';
    await runMigrations();
    app = buildApp();
    await app.ready();
  });

  afterAll(async () => {
    await app.close();
    await closePool();
  });

  it('GET /health returns 200 and status healthy', async () => {
    const res = await app.inject({ method: 'GET', url: '/health' });
    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.body);
    expect(body.status).toBe('healthy');
  });

  it('POST /api/v1/auth/register blocks underage registration', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/register',
      payload: {
        email: `underage_api_${Date.now()}@forma.local`,
        password: 'Password123!',
        dateOfBirth: '2015-01-01',
        heightCm: 160,
        consents: { termsOfService: true, healthDataProcessing: true, aiThirdPartyProcessing: true }
      }
    });

    expect(res.statusCode).toBe(400);
    expect(JSON.parse(res.body).error).toMatch(/users must be at least 18 years old/);
  });

  it('POST /api/v1/auth/register successfully registers User A and User B', async () => {
    // Register User A
    const resA = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/register',
      payload: {
        email: `api_user_a_${Date.now()}@forma.local`,
        password: 'Password123!',
        dateOfBirth: '1990-05-15',
        heightCm: 180,
        sexForCalculation: 'male',
        locale: 'en',
        numeralSystem: 'western',
        consents: { termsOfService: true, healthDataProcessing: true, aiThirdPartyProcessing: true }
      }
    });
    expect(resA.statusCode).toBe(201);
    const bodyA = JSON.parse(resA.body);
    userAToken = bodyA.tokens.accessToken;
    userAId = bodyA.user.id;

    // Register User B
    const resB = await app.inject({
      method: 'POST',
      url: '/api/v1/auth/register',
      payload: {
        email: `api_user_b_${Date.now()}@forma.local`,
        password: 'Password123!',
        dateOfBirth: '1995-10-20',
        heightCm: 165,
        sexForCalculation: 'female',
        locale: 'ar',
        numeralSystem: 'eastern_arabic',
        consents: { termsOfService: true, healthDataProcessing: true, aiThirdPartyProcessing: true }
      }
    });
    expect(resB.statusCode).toBe(201);
    userBToken = JSON.parse(resB.body).tokens.accessToken;
  });

  it('rejects unauthenticated requests with 401', async () => {
    const res = await app.inject({ method: 'GET', url: '/api/v1/profile' });
    expect(res.statusCode).toBe(401);
  });

  it('GET /api/v1/profile returns authenticated user profile', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/profile',
      headers: { authorization: `Bearer ${userAToken}` }
    });
    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.body);
    expect(body.userId).toBe(userAId);
    expect(body.heightCm).toBe(180);
  });

  it('PUT /api/v1/profile updates profile and records attribute history', async () => {
    const res = await app.inject({
      method: 'PUT',
      url: '/api/v1/profile',
      headers: { authorization: `Bearer ${userAToken}` },
      payload: { heightCm: 181.5, activityLevel: 'very_active' }
    });
    expect(res.statusCode).toBe(200);
    expect(JSON.parse(res.body).heightCm).toBe(181.5);

    const histRes = await app.inject({
      method: 'GET',
      url: '/api/v1/profile/history',
      headers: { authorization: `Bearer ${userAToken}` }
    });
    expect(histRes.statusCode).toBe(200);
    const history = JSON.parse(histRes.body).history;
    expect(history.some((h: any) => h.attributeName === 'height_cm')).toBe(true);
  });

  it('POST /api/v1/measurements/observations records observation with provenance', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/v1/measurements/observations',
      headers: { authorization: `Bearer ${userAToken}` },
      payload: {
        typeCode: 'weight',
        value: 175.5,
        unit: 'lb',
        observedAt: new Date().toISOString(),
        originType: 'manual_entry',
        epistemicClass: 'measured'
      }
    });

    expect(res.statusCode).toBe(201);
    const body = JSON.parse(res.body);
    expect(body.observation.canonical_unit).toBe('kg');
    expect(body.observation.original_value).toBe(175.5);
    expect(body.observation.original_unit).toBe('lb');
    expect(body.provenance.id).toBe(body.observation.provenance_id);
    observationAId = body.observation.id;
  });

  it('POST /api/v1/measurements/observations/:id/supersede corrects observation', async () => {
    const res = await app.inject({
      method: 'POST',
      url: `/api/v1/measurements/observations/${observationAId}/supersede`,
      headers: { authorization: `Bearer ${userAToken}` },
      payload: {
        newValue: 176.0,
        newUnit: 'lb',
        correctionReason: 'Recalibrated scale reading'
      }
    });

    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.body);
    expect(body.newObservation.supersedes).toBe(observationAId);
    expect(body.previousObservation.status).toBe('superseded');
  });

  it('enforces API user isolation: User B cannot supersede or view User A observation', async () => {
    const res = await app.inject({
      method: 'POST',
      url: `/api/v1/measurements/observations/${observationAId}/supersede`,
      headers: { authorization: `Bearer ${userBToken}` },
      payload: {
        newValue: 200.0,
        newUnit: 'lb',
        correctionReason: 'Unauthorized cross-user modification'
      }
    });

    // Should fail with 400/404 because User B cannot access User A's observation under RLS
    expect(res.statusCode).toBeGreaterThanOrEqual(400);
  });

  it('GET /api/v1/privacy/export returns portable export without secrets', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/api/v1/privacy/export',
      headers: { authorization: `Bearer ${userAToken}` }
    });

    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.body);
    expect(body.userId).toBe(userAId);
    expect(body.modules.identity).toBeDefined();
    expect(body.modules.profile).toBeDefined();
    expect(body.modules.measurements).toBeDefined();

    // Verify secrets are NOT exposed
    const exportString = JSON.stringify(body);
    expect(exportString).not.toMatch(/passwordHash/i);
    expect(exportString).not.toMatch(/refreshTokenHash/i);
    expect(body.modules.goals).toBeDefined();
    expect(body.modules.analytics).toBeDefined();
  });

  it('Phase 2 Goals & Versions Endpoints', async () => {
    // Create Goal
    const createRes = await app.inject({
      method: 'POST',
      url: '/api/v1/goals',
      headers: { authorization: `Bearer ${userAToken}` },
      payload: {
        goalType: 'weight_loss',
        targetMetricTypeCode: 'weight',
        startingValue: 90.0,
        targetValue: 80.0,
        weeklyRate: 0.5,
        startDate: '2026-10-01',
        isPrimary: true
      }
    });

    expect(createRes.statusCode).toBe(201);
    const goal = JSON.parse(createRes.body);
    expect(goal.isPrimary).toBe(true);
    expect(goal.currentVersion.version).toBe(1);

    // Get Primary Goal
    const primaryRes = await app.inject({
      method: 'GET',
      url: '/api/v1/goals/primary',
      headers: { authorization: `Bearer ${userAToken}` }
    });
    expect(primaryRes.statusCode).toBe(200);
    expect(JSON.parse(primaryRes.body).goal.id).toBe(goal.id);

    // Add Goal Version
    const verRes = await app.inject({
      method: 'POST',
      url: `/api/v1/goals/${goal.id}/versions`,
      headers: { authorization: `Bearer ${userAToken}` },
      payload: {
        targetValue: 78.0,
        rationale: 'Adjusted target'
      }
    });
    expect(verRes.statusCode).toBe(200);
    expect(JSON.parse(verRes.body).currentVersion.version).toBe(2);
    expect(JSON.parse(verRes.body).currentVersion.targetValue).toBe(78.0);
  });

  it('Phase 2 Pure Calculation Endpoints', async () => {
    // BMI
    const bmiRes = await app.inject({
      method: 'GET',
      url: '/api/v1/calculations/bmi?weightKg=70&heightCm=175'
    });
    expect(bmiRes.statusCode).toBe(200);
    expect(JSON.parse(bmiRes.body).value).toBe(22.9);

    // BMR
    const bmrRes = await app.inject({
      method: 'GET',
      url: '/api/v1/calculations/bmr?weightKg=80&heightCm=180&ageYears=30&sex=male'
    });
    expect(bmrRes.statusCode).toBe(200);
    expect(JSON.parse(bmrRes.body).value).toBe(1780);

    // TDEE
    const tdeeRes = await app.inject({
      method: 'GET',
      url: '/api/v1/calculations/tdee?bmr=1780&activityLevel=moderately_active'
    });
    expect(tdeeRes.statusCode).toBe(200);
    expect(JSON.parse(tdeeRes.body).value).toBe(Math.round(1780 * 1.55));

    // Calorie Targets
    const targetsRes = await app.inject({
      method: 'GET',
      url: '/api/v1/calculations/calorie-targets?tdee=2500&sex=male'
    });
    expect(targetsRes.statusCode).toBe(200);
    expect(JSON.parse(targetsRes.body).targets.standardLoss.targetCalories).toBe(2000);

    // Macros
    const macrosRes = await app.inject({
      method: 'GET',
      url: '/api/v1/calculations/macros?targetCalories=2000&weightKg=70'
    });
    expect(macrosRes.statusCode).toBe(200);
    expect(JSON.parse(macrosRes.body).proteinGrams).toBe(126);

    // Timeline
    const timelineRes = await app.inject({
      method: 'GET',
      url: '/api/v1/calculations/timeline?currentWeightKg=85&targetWeightKg=80&weeklyRateKg=0.5'
    });
    expect(timelineRes.statusCode).toBe(200);
    expect(JSON.parse(timelineRes.body).estimatedWeeks).toBe(10);
  });

  it('Phase 2 Health Snapshot & Trends Endpoints', async () => {
    // Snapshot
    const snapRes = await app.inject({
      method: 'GET',
      url: '/api/v1/analytics/snapshot',
      headers: { authorization: `Bearer ${userAToken}` }
    });
    expect(snapRes.statusCode).toBe(200);
    const snap = JSON.parse(snapRes.body);
    expect(snap.userId).toBe(userAId);
    expect(snap.sections.identityLite).toBeDefined();
    expect(snap.sections.bodyStatus).toBeDefined();
    expect(snap.sections.goal).toBeDefined();

    // Reconcile
    const recRes = await app.inject({
      method: 'GET',
      url: '/api/v1/analytics/snapshot/reconcile',
      headers: { authorization: `Bearer ${userAToken}` }
    });
    expect(recRes.statusCode).toBe(200);
    expect(JSON.parse(recRes.body).isDriftDetected).toBe(false);

    // Trends
    const trendRes = await app.inject({
      method: 'GET',
      url: '/api/v1/analytics/trends/weight?windowDays=30',
      headers: { authorization: `Bearer ${userAToken}` }
    });
    expect(trendRes.statusCode).toBe(200);
    expect(JSON.parse(trendRes.body).typeCode).toBe('weight');
  });

  it('Phase 3 AI Configuration & BYOK Management Endpoints', async () => {
    // 1. GET /api/v1/ai/config
    const configRes = await app.inject({
      method: 'GET',
      url: '/api/v1/ai/config',
      headers: { authorization: `Bearer ${userAToken}` },
    });
    expect(configRes.statusCode).toBe(200);
    const configBody = JSON.parse(configRes.body);
    expect(configBody.availableProviders).toContain('google');
    expect(configBody.availableProviders).toContain('openai');
    expect(configBody.models.length).toBeGreaterThan(0);

    // 2. POST /api/v1/ai/test-connection
    const testConnRes = await app.inject({
      method: 'POST',
      url: '/api/v1/ai/test-connection',
      headers: { authorization: `Bearer ${userAToken}` },
      payload: { provider: 'google', apiKey: 'valid-test-key-12345' },
    });
    expect(testConnRes.statusCode).toBe(200);
    expect(JSON.parse(testConnRes.body).status).toBe('success');

    // 3. POST /api/v1/ai/credentials
    const storeCredRes = await app.inject({
      method: 'POST',
      url: '/api/v1/ai/credentials',
      headers: { authorization: `Bearer ${userAToken}` },
      payload: { provider: 'google', apiKey: 'user-private-key-12345678' },
    });
    expect(storeCredRes.statusCode).toBe(201);
    const credBody = JSON.parse(storeCredRes.body);
    expect(credBody.credential.provider).toBe('google');
    expect(credBody.credential.keyFingerprint).toBe('...5678');
    expect(credBody.credential).not.toHaveProperty('encryptedKey');

    // 4. Verify credential shows in config
    const configWithCredRes = await app.inject({
      method: 'GET',
      url: '/api/v1/ai/config',
      headers: { authorization: `Bearer ${userAToken}` },
    });
    expect(configWithCredRes.statusCode).toBe(200);
    const creds = JSON.parse(configWithCredRes.body).credentials;
    expect(creds.some((c: any) => c.provider === 'google')).toBe(true);

    // 5. DELETE /api/v1/ai/credentials/:provider (with application/json header to ensure empty body parser compatibility)
    const deleteCredRes = await app.inject({
      method: 'DELETE',
      url: '/api/v1/ai/credentials/google',
      headers: {
        authorization: `Bearer ${userAToken}`,
        'content-type': 'application/json',
      },
    });
    expect(deleteCredRes.statusCode).toBe(200);
    expect(JSON.parse(deleteCredRes.body).success).toBe(true);
  });

  it('DELETE /api/v1/privacy/account executes irreversible account purge', async () => {
    const res = await app.inject({
      method: 'DELETE',
      url: '/api/v1/privacy/account',
      headers: { authorization: `Bearer ${userAToken}` }
    });

    expect(res.statusCode).toBe(200);
    expect(JSON.parse(res.body).success).toBe(true);

    // Verify token can no longer access profile
    const profileRes = await app.inject({
      method: 'GET',
      url: '/api/v1/profile',
      headers: { authorization: `Bearer ${userAToken}` }
    });
    expect(profileRes.statusCode).toBe(404);
  });
});
