import { describe, it, expect } from 'vitest';
import { SnapshotEngine } from './snapshot.js';
import { ObservationService } from '../measurements/model.js';
import { GoalService } from '../goals/model.js';
import { UserProfile } from '../profile/model.js';

describe('Health Snapshot Engine (ADR-019, §7.8)', () => {
  const mockProfile: UserProfile = {
    userId: 'user_snap_1',
    heightCm: 180,
    sexForCalculation: 'male',
    dateOfBirth: '1995-05-15',
    activityLevel: 'moderately_active',
    preferredLanguage: 'en',
    preferredNumeralSystem: 'western',
    preferredUnits: { mass: 'kg', length: 'cm', energy: 'kcal' },
    attributes: {},
    calculationSnapshots: [],
    updatedAt: new Date().toISOString(),
  };

  it('generates a complete Health Snapshot from profile, observations and goals', () => {
    const obs1 = ObservationService.createObservation({
      id: 'obs_1',
      userId: 'user_snap_1',
      typeCode: 'weight',
      value: 85.0,
      unit: 'kg',
      observedAt: '2026-09-01T10:00:00Z',
    }).observation;

    const obs2 = ObservationService.createObservation({
      id: 'obs_2',
      userId: 'user_snap_1',
      typeCode: 'weight',
      value: 83.5,
      unit: 'kg',
      observedAt: '2026-09-15T10:00:00Z',
    }).observation;

    const obs3 = ObservationService.createObservation({
      id: 'obs_3',
      userId: 'user_snap_1',
      typeCode: 'weight',
      value: 82.0,
      unit: 'kg',
      observedAt: '2026-09-29T10:00:00Z',
    }).observation;

    const goal = GoalService.createGoal({
      id: 'goal_1',
      userId: 'user_snap_1',
      type: 'weight_loss',
      isPrimary: true,
      targetMetricCode: 'weight',
      targetCanonicalValue: 78.0,
      targetCanonicalUnit: 'kg',
      baselineCanonicalValue: 85.0,
    });

    const snapshot = SnapshotEngine.generateSnapshot({
      profile: mockProfile,
      observations: [obs1, obs2, obs3],
      goals: [goal],
    });

    // Check Identity Lite
    expect(snapshot.userId).toBe('user_snap_1');
    expect(snapshot.sections.identityLite.data.heightCm).toBe(180);
    expect(snapshot.sections.identityLite.data.ageYears).toBeGreaterThan(25);

    // Check Body Status
    expect(snapshot.sections.bodyStatus.data.latestWeightKg).toBe(82.0);
    expect(snapshot.sections.bodyStatus.data.weightTrendRatePerWeek).toBeLessThan(0); // Losing weight

    // Check Primary Goal Progress
    expect(snapshot.sections.primaryGoal).toBeDefined();
    expect(snapshot.sections.primaryGoal?.data.targetValue).toBe(78.0);
    expect(snapshot.sections.primaryGoal?.data.currentValue).toBe(82.0);
    // Baseline 85 -> Target 78 (7kg total). Current 82 -> 3kg lost. 3/7 = ~43%
    expect(snapshot.sections.primaryGoal?.data.progressPercentage).toBe(43);
    expect(snapshot.sections.primaryGoal?.data.isAchieved).toBe(false);

    // Check Energy section
    expect(snapshot.sections.energy.data.bmrKcal).toBeGreaterThan(1500);
    expect(snapshot.sections.energy.data.targetCalories).toBeLessThan(snapshot.sections.energy.data.tdeeKcal); // Deficit applied
  });

  it('detects drift between cached and recomputed snapshots (§7.8 rule 6)', () => {
    const obs = [
      ObservationService.createObservation({
        id: 'obs_w',
        userId: 'user_snap_1',
        typeCode: 'weight',
        value: 80.0,
        unit: 'kg',
      }).observation,
    ];

    const cached = SnapshotEngine.generateSnapshot({
      profile: mockProfile,
      observations: obs,
      goals: [],
    });

    // Modify weight in fresh recomputation
    const updatedObs = [
      ObservationService.createObservation({
        id: 'obs_w2',
        userId: 'user_snap_1',
        typeCode: 'weight',
        value: 75.0, // Weight dropped
        unit: 'kg',
      }).observation,
    ];

    const fresh = SnapshotEngine.generateSnapshot({
      profile: mockProfile,
      observations: updatedObs,
      goals: [],
    });

    const reconciliation = SnapshotEngine.reconcile(cached, fresh);
    expect(reconciliation.hasDrift).toBe(true);
    expect(reconciliation.driftFields).toContain('bodyStatus.latestWeightKg');
  });
});
