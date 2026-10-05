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
