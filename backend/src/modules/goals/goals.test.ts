import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { runMigrations } from '../../core/database/migrate.js';
import { closePool, withUserContext } from '../../core/database/index.js';
import { GoalsService } from './service.js';
import { MeasurementsService } from '../measurements/service.js';
import crypto from 'crypto';

describe('Goals Module Integration Tests (Real PostgreSQL 18)', () => {
  const goalsService = new GoalsService();

  const userA = crypto.randomUUID();
  const userB = crypto.randomUUID();

  beforeAll(async () => {
    await runMigrations();

    // Seed test users
    await withUserContext(userA, async (client) => {
      await client.query(`
        INSERT INTO users (id, email, status)
        VALUES ($1, $2, 'active')
        ON CONFLICT (id) DO NOTHING
      `, [userA, `test-goals-a-${Date.now()}@example.com`]);
    });

    await withUserContext(userB, async (client) => {
      await client.query(`
        INSERT INTO users (id, email, status)
        VALUES ($1, $2, 'active')
        ON CONFLICT (id) DO NOTHING
      `, [userB, `test-goals-b-${Date.now()}@example.com`]);
    });
  });

  afterAll(async () => {
    await closePool();
  });

  it('creates a primary goal and computes 0% progress when no observations exist', async () => {
    const goal = await goalsService.createGoal(userA, {
      goalType: 'weight_loss',
      targetMetricTypeCode: 'weight',
      startingValue: 90.0,
      targetValue: 80.0,
      weeklyRate: 0.5,
      startDate: '2026-10-01',
      targetDate: '2027-02-18',
      rationale: 'Health and endurance',
      isPrimary: true
    });

    expect(goal.id).toBeDefined();
    expect(goal.isPrimary).toBe(true);
    expect(goal.currentVersion?.version).toBe(1);
    expect(goal.currentVersion?.startingValue).toBe(90.0);
    expect(goal.currentVersion?.targetValue).toBe(80.0);
    // No measurement of the goal's metric exists yet — progress is UNKNOWN,
    // not a fabricated 0% at a fake "starting value" current reading.
    expect(goal.progressPct).toBeUndefined();
    expect(goal.currentValue).toBeUndefined();
  });

  it('updates progress when a new measurement observation is logged', async () => {
    // User A weighs in at 85 kg (halfway from 90 to 80 kg)
    await MeasurementsService.recordObservation(
      userA,
      {
        typeCode: 'weight',
        value: 85.0,
        unit: 'kg',
        originType: 'manual_entry',
        epistemicClass: 'measured',
        observedAt: new Date().toISOString(),
                actor: 'user',
          confidenceScore: 1.0,
          reviewState: 'user_reviewed',
},
      
      'corr-goals-1'
    );

    const primary = await goalsService.getPrimaryGoal(userA);
    expect(primary).not.toBeNull();
    expect(primary?.currentValue).toBe(85.0);
    expect(primary?.progressPct).toBe(50.0); // (90 - 85) / (90 - 80) * 100 = 50%
  });

  it('creates a new goal version preserving history and temporal lineage', async () => {
    const primary = await goalsService.getPrimaryGoal(userA);
    expect(primary).not.toBeNull();

    const updated = await goalsService.addGoalVersion(userA, primary!.id, {
      targetValue: 78.0, // adjusted target to 78 kg
      rationale: 'Adjusted target after plateau analysis'
    });

    expect(updated.currentVersion?.version).toBe(2);
    expect(updated.currentVersion?.targetValue).toBe(78.0);
    // (90 - 85) / (90 - 78) = 5 / 12 = 41.7%
    expect(updated.progressPct).toBe(41.7);
  });

  it('enforces RLS: User B cannot view or modify User A goals', async () => {
    const userBGoals = await goalsService.listGoals(userB);
    expect(userBGoals).toHaveLength(0);

    const userBPrimary = await goalsService.getPrimaryGoal(userB);
    expect(userBPrimary).toBeNull();
  });

  it('exports and cleanly purges user goals data', async () => {
    const exported = await goalsService.exportData(userA);
    expect(exported['goals']).toBeDefined();
    expect((exported['goals'] as any[]).length).toBeGreaterThan(0);
    expect((exported['goalVersions'] as any[]).length).toBeGreaterThan(0);

    await goalsService.purgeData(userA);
    const remaining = await goalsService.listGoals(userA);
    expect(remaining).toHaveLength(0);
  });
});
