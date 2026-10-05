import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { closePool } from '../../core/database/index.js';
import { runMigrations } from '../../core/database/migrate.js';
import { IdentityService } from './service.js';

describe('Identity Service Integration Tests (Real PostgreSQL)', () => {
  beforeAll(async () => {
    process.env['NODE_ENV'] = 'test';
    await runMigrations();
  });

  afterAll(async () => {
    await closePool();
  });

  it('blocks registration for underage users (< 18 years old)', async () => {
    const today = new Date();
    const underageDob = new Date(today.getFullYear() - 16, today.getMonth(), today.getDate())
      .toISOString().split('T')[0]!;

    await expect(
      IdentityService.register(
        {
          email: 'underage@forma.local',
          password: 'Password123!',
          dateOfBirth: underageDob,
          heightCm: 175,
          sexForCalculation: 'male',
          locale: 'en',
          numeralSystem: 'western',
          consents: {
            termsOfService: true,
            healthDataProcessing: true,
            aiThirdPartyProcessing: true
          }
        },
        'corr-underage-test'
      )
    ).rejects.toThrow(/users must be at least 18 years old/);
  });

  it('successfully registers an adult user with credentials, consents, and initial profile', async () => {
    const email = `adult_${Date.now()}@forma.local`;
    const res = await IdentityService.register(
      {
        email,
        password: 'SecurePassword123!',
        dateOfBirth: '1995-06-15',
        heightCm: 180,
        sexForCalculation: 'male',
        locale: 'en',
        numeralSystem: 'western',
        consents: {
          termsOfService: true,
          healthDataProcessing: true,
          aiThirdPartyProcessing: true
        }
      },
      'corr-reg-adult'
    );

    expect(res.user.id).toBeDefined();
    expect(res.user.email).toBe(email);
    expect(res.tokens.accessToken).toBeDefined();
    expect(res.tokens.refreshToken).toBeDefined();
  });

  it('authenticates user and rotates refresh tokens with reuse detection', async () => {
    const email = `session_user_${Date.now()}@forma.local`;
    await IdentityService.register(
      {
        email,
        password: 'MyPassword123!',
        dateOfBirth: '1990-01-01',
        heightCm: 170,
        sexForCalculation: 'female',
        locale: 'ar',
        numeralSystem: 'eastern_arabic',
        consents: {
          termsOfService: true,
          healthDataProcessing: true,
          aiThirdPartyProcessing: true
        }
      },
      'corr-session-reg'
    );

    // Login
    const loginRes = await IdentityService.login(
      { email, password: 'MyPassword123!' },
      'corr-login'
    );
    expect(loginRes.tokens.accessToken).toBeDefined();
    const token1 = loginRes.tokens.refreshToken;

    // First rotation using token1 -> should succeed
    const refresh1 = await IdentityService.refreshTokens(
      { refreshToken: token1 },
      'corr-refresh-1'
    );
    expect(refresh1.tokens.refreshToken).not.toBe(token1);
    const token2 = refresh1.tokens.refreshToken;

    // Second rotation using token2 -> should succeed
    const refresh2 = await IdentityService.refreshTokens(
      { refreshToken: token2 },
      'corr-refresh-2'
    );
    expect(refresh2.tokens.refreshToken).not.toBe(token2);

    // REUSE ATTACK: Attempting to reuse already rotated token1!
    // Must trigger session family revocation!
    await expect(
      IdentityService.refreshTokens({ refreshToken: token1 }, 'corr-reuse-attack')
    ).rejects.toThrow(/Refresh token reuse detected/);

    // Verify that subsequent use of token2 or even the latest valid token is also revoked!
    await expect(
      IdentityService.refreshTokens({ refreshToken: refresh2.tokens.refreshToken }, 'corr-family-revoked')
    ).rejects.toThrow();
  });
});
