import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { closePool } from '../../core/database/index.js';
import { runMigrations } from '../../core/database/migrate.js';
import { IdentityService } from '../identity/service.js';
import { ProfileService } from './service.js';

describe('Profile & Versioned Computational Attributes Integration Tests', () => {
  let userId: string;

  beforeAll(async () => {
    process.env['NODE_ENV'] = 'test';
    await runMigrations();

    const auth = await IdentityService.register(
      {
        email: `profile_test_${Date.now()}@forma.local`,
        password: 'Password123!',
        dateOfBirth: '1994-08-10',
        heightCm: 175,
        sexForCalculation: 'male',
        locale: 'en',
        numeralSystem: 'western',
        consents: { termsOfService: true, healthDataProcessing: true, aiThirdPartyProcessing: true }
      },
      'corr-prof-init'
    );
    userId = auth.user.id;
  });

  afterAll(async () => {
    await closePool();
  });

  it('retrieves user profile accurately', async () => {
    const profile = await ProfileService.getProfile(userId);
    expect(profile).not.toBeNull();
    expect(profile?.heightCm).toBe(175);
    expect(profile?.sexForCalculation).toBe('male');
    expect(profile?.activityLevel).toBe('sedentary');
  });

  it('updates calculation-relevant attributes and records history for reproducibility', async () => {
    // 1. Update height
    const updated = await ProfileService.updateProfile(
      userId,
      {
        heightCm: 176.5,
        activityLevel: 'moderately_active'
      },
      'corr-prof-update'
    );

    expect(updated.heightCm).toBe(176.5);
    expect(updated.activityLevel).toBe('moderately_active');

    // 2. Verify history trail
    const history = await ProfileService.getHistory(userId);
    expect(history.length).toBeGreaterThanOrEqual(4); // 2 from onboarding + 2 from update

    const heightHistory = history.filter(h => h.attributeName === 'height_cm');
    expect(heightHistory.length).toBe(2);
    expect(heightHistory[0]?.oldValue).toBe(175);
    expect(heightHistory[0]?.newValue).toBe(176.5);

    const activityHistory = history.filter(h => h.attributeName === 'activity_level');
    expect(activityHistory.length).toBe(1);
    expect(activityHistory[0]?.oldValue).toBe('sedentary');
    expect(activityHistory[0]?.newValue).toBe('moderately_active');
  });
});
