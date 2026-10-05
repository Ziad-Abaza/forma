import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { buildApp } from '../app.js';
import { closePool } from '../core/database/index.js';
import { sanitizeLogData } from '../core/logging/index.js';
import type { FastifyInstance } from 'fastify';

describe('Gate 12: Observability, Health Probes & Redaction Audit', () => {
  let app: FastifyInstance;

  beforeAll(async () => {
    app = buildApp();
    await app.ready();
  });

  afterAll(async () => {
    await app.close();
    await closePool();
  });

  it('GET /health returns 200 with service liveness status and version', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/health'
    });

    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.payload);
    expect(body.status).toBe('healthy');
    expect(body.version).toBe('1.0.0');
    expect(body.timestamp).toBeDefined();
  });

  it('GET /health/live returns process uptime telemetry', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/health/live'
    });

    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.payload);
    expect(body.status).toBe('healthy');
    expect(typeof body.uptimeSeconds).toBe('number');
    expect(body.uptimeSeconds).toBeGreaterThanOrEqual(0);
    expect(body.timestamp).toBeDefined();
  });

  it('GET /health/ready verifies database connectivity and returns 200', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/health/ready'
    });

    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.payload);
    expect(body.status).toBe('ready');
    expect(body.database).toBe('connected');
    expect(body.timestamp).toBeDefined();
  });

  it('GET /metrics returns structured operational metrics and memory stats', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/metrics'
    });

    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.payload);
    expect(body.status).toBe('operational');
    expect(body.memory).toBeDefined();
    expect(typeof body.memory.heapUsed).toBe('number');
    expect(typeof body.uptimeSeconds).toBe('number');
  });

  it('sanitizeLogData sanitizes secrets, tokens, passwords, and sensitive health values', () => {
    const sensitivePayload = {
      user_id: 'usr_test_123',
      email: 'user@example.com',
      password: 'SuperSecretPassword123!',
      refreshToken: 'rf_xyz_token_secret',
      apiKey: 'ai-secret-key-12345',
      authorization: 'Bearer token-value-here',
      bloodGlucose: 105,
      weightKg: 78.5,
      systolic: 120,
      imageBase64: 'data:image/jpeg;base64,sensitive_biometric_data',
      nested: {
        token: 'nested-token',
        prompt: 'User private medical history question',
        safeMetric: 'count_of_steps'
      }
    };

    const sanitized = sanitizeLogData(sensitivePayload);

    // Identity and credentials must be redacted
    expect(sanitized.password).toBe('[REDACTED]');
    expect(sanitized.refreshToken).toBe('[REDACTED]');
    expect(sanitized.apiKey).toBe('[REDACTED]');
    expect(sanitized.authorization).toBe('[REDACTED]');
    expect(sanitized.imageBase64).toBe('[REDACTED]');

    // Biometric/health values must never be in logs (Blueprint §32 Invariant 13)
    expect(sanitized.bloodGlucose).toBe('[REDACTED]');
    expect(sanitized.weightKg).toBe('[REDACTED]');
    expect(sanitized.systolic).toBe('[REDACTED]');

    // Nested redactions
    expect(sanitized.nested.token).toBe('[REDACTED]');
    expect(sanitized.nested.prompt).toBe('[REDACTED]');
    expect(sanitized.nested.safeMetric).toBe('count_of_steps');

    // Safe fields preserved
    expect(sanitized.user_id).toBe('usr_test_123');
    expect(sanitized.email).toBe('user@example.com');
  });
});
