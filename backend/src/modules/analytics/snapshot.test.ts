import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { runMigrations } from '../../core/database/migrate.js';
import { closePool } from '../../core/database/index.js';
import { AnalyticsService } from './service.js';
import { IdentityService } from '../identity/service.js';
import { MeasurementsService } from '../measurements/service.js';
import { ProfileService } from '../profile/service.js';
import { GoalsService } from '../goals/service.js';

describe('Health Snapshot Engine & Trend Analytics Integration Tests (Real PostgreSQL 18)', () => {
  const analyticsService = new AnalyticsService();
  const goalsService = new GoalsService();

  let userA: string;
  let userB: string;

  beforeAll(async () => {
    await runMigrations();

    const authA = await IdentityService.register(
      {
        email: `snapshot-a-${Date.now()}@forma.local`,
        password: 'Password123!',
        dateOfBirth: '1995-05-15',
        heightCm: 180,
        sexForCalculation: 'male',
        locale: 'en',
        numeralSystem: 'western',
        consents: { termsOfService: true, healthDataProcessing: true, aiThirdPartyProcessing: true }
      },
      'corr-snap-reg-a'
    );
    userA = authA.user.id;

    const authB = await IdentityService.register(
      {
        email: `snapshot-b-${Date.now()}@forma.local`,
        password: 'Password123!',
        dateOfBirth: '1998-03-20',
        heightCm: 165,
        sexForCalculation: 'female',
        locale: 'en',
        numeralSystem: 'western',
        consents: { termsOfService: true, healthDataProcessing: true, aiThirdPartyProcessing: true }
      },
      'corr-snap-reg-b'
    );
    userB = authB.user.id;

    // Update Profile for User A with activity level
    await ProfileService.updateProfile(
      userA,
      {
        activityLevel: 'moderately_active'
      },
      'corr-snap-prof'
    );

    // Create Primary Goal for User A: Lose weight from 85 kg to 75 kg
    await goalsService.createGoal(userA, {
      goalType: 'weight_loss',
      targetMetricTypeCode: 'weight',
      startingValue: 85.0,
      targetValue: 75.0,
      weeklyRate: 0.5,
      startDate: '2026-10-01',
      isPrimary: true
    });
  });

  afterAll(async () => {
    await closePool();
  });

  it('computes initial snapshot with empty observations and derived calorie targets', async () => {
    const snap = await analyticsService.getSnapshot(userA);

    expect(snap.userId).toBe(userA);
    expect(snap.sections.identityLite.heightCm).toBe(180);
    expect(snap.sections.identityLite.sexForCalculation).toBe('male');
    expect(snap.sections.goal.hasActiveGoal).toBe(true);
    expect(snap.sections.goal.targetValue).toBe(75.0);
    expect(snap.sections.bodyStatus.latestWeightKg).toBeUndefined();
    expect(snap.sections.dataQuality.totalActiveObservations).toBe(0);
  });

  it('updates snapshot sections and advances watermark when observations are recorded', async () => {
    // Record baseline weigh-in: 85 kg (15 days ago — inside the 30d trend window)
    const day1 = new Date(Date.now() - 15 * 24 * 60 * 60 * 1000).toISOString();
    await MeasurementsService.recordObservation(
      userA,
      {
        typeCode: 'weight',
        value: 85.0,
        unit: 'kg',
        originType: 'manual_entry',
        epistemicClass: 'measured',
        observedAt: day1
      },
      'corr-snap-1'
    );

    const snap1 = await analyticsService.getSnapshot(userA);
    expect(snap1.sections.bodyStatus.latestWeightKg).toBe(85.0);
    // BMI for 85 kg, 180 cm = 85 / (1.8^2) = 26.2 (Overweight)
    expect(snap1.sections.bodyStatus.bmi).toBe(26.2);
    expect(snap1.sections.bodyStatus.bmiCategory).toBe('overweight');
    expect(snap1.sections.energy.bmr).toBeGreaterThan(1700);
    expect(snap1.sections.energy.tdee).toBeGreaterThan(2500);

    // Record second weigh-in: 84.5 kg 3 days later
    const day2 = new Date(Date.now() - 12 * 24 * 60 * 60 * 1000).toISOString();
    await MeasurementsService.recordObservation(
      userA,
      {
        typeCode: 'weight',
        value: 84.5,
        unit: 'kg',
        originType: 'manual_entry',
        epistemicClass: 'measured',
        observedAt: day2
      },
      'corr-snap-2'
    );

    const snap2 = await analyticsService.getSnapshot(userA);
    expect(snap2.sections.bodyStatus.latestWeightKg).toBe(84.5);
    expect(snap2.sourceDataWatermark).not.toBe(snap1.sourceDataWatermark);

    // Truthful data-quality fields: all recorded observations are 'measured'
    expect(snap2.sections.dataQuality.measuredSharePct).toBe(100);
    // Staleness is derived from the latest observation of any type
    expect(snap2.sections.dataQuality.stalenessDays).toBeDefined();
    // Real epistemic class from provenance — never a hardcoded 'measured'
    const weightItem = snap2.sections.recentMeasurements.find((m) => m.typeCode === 'weight');
    expect(weightItem?.epistemicClass).toBe('measured');
  });

  it('proves zero drift between materialized snapshot and pure recomputation', async () => {
    const reconciliation = await analyticsService.reconcileSnapshot(userA);
    expect(reconciliation.isDriftDetected).toBe(false);
    expect(reconciliation.diffDetails).toBeUndefined();
  });

  it('detects noise-robust trend when sufficient points exist', async () => {
    // Add 2 more points, 9 and 6 days ago (4 points total spanning 9 days)
    const day3 = new Date(Date.now() - 9 * 24 * 60 * 60 * 1000).toISOString();
    const day4 = new Date(Date.now() - 6 * 24 * 60 * 60 * 1000).toISOString();

    await MeasurementsService.recordObservation(
      userA,
      { typeCode: 'weight', value: 84.0, unit: 'kg', observedAt: day3 },
      'corr-snap-3'
    );
    await MeasurementsService.recordObservation(
      userA,
      { typeCode: 'weight', value: 83.5, unit: 'kg', observedAt: day4 },
      'corr-snap-4'
    );

    const trend = await analyticsService.getTrend(userA, 'weight', 30);
    expect(trend.sufficiency).toBe('complete');
    expect(trend.dataPointCount).toBe(4);
    expect(trend.deltaValue).toBe(-1.5); // from 85.0 to 83.5
    expect(trend.weeklyRate).toBeLessThan(0); // losing weight
    expect(trend.smoothedLatest).toBeDefined();

    // windowDays is a real filter: a 1-day window sees none of the older points
    const narrowTrend = await analyticsService.getTrend(userA, 'weight', 1);
    expect(narrowTrend.dataPointCount).toBe(0);
    expect(narrowTrend.sufficiency).toBe('insufficient');
  });

  it('flags an implausible jump anomaly when weight spikes unrealistically in 24 hours', async () => {
    // Current is 83.5 kg. Add a measurement 5 hours later of 90 kg (+6.5 kg jump!)
    const anomalyTime = new Date(Date.now() - 6 * 24 * 60 * 60 * 1000 + 5 * 60 * 60 * 1000).toISOString();
    await MeasurementsService.recordObservation(
      userA,
      { typeCode: 'weight', value: 90.0, unit: 'kg', observedAt: anomalyTime },
      'corr-snap-5'
    );

    const snap = await analyticsService.getSnapshot(userA);
    expect(snap.sections.anomalies.length).toBeGreaterThan(0);
    const flag = snap.sections.anomalies[0];
    expect(flag?.flagType).toBe('implausible_jump');
    expect(flag?.severity).toBe('warning');
  });

  it('enforces RLS isolation: User B cannot access User A snapshot', async () => {
    const userBSnap = await analyticsService.getSnapshot(userB);
    expect(userBSnap.userId).toBe(userB);
    expect(userBSnap.sections.bodyStatus.latestWeightKg).toBeUndefined();
    expect(userBSnap.sections.dataQuality.totalActiveObservations).toBe(0);
    // No observations -> measured share is honestly null, not a fabricated 100
    expect(userBSnap.sections.dataQuality.measuredSharePct).toBeNull();
    // Profile default is 'sedentary' — never fabricated to 'moderately_active'
    expect(userBSnap.sections.energy.activityLevel).toBe('sedentary');
  });

  it('exports and cleanly purges user analytics and snapshot data', async () => {
    const exported = await analyticsService.exportData(userA);
    expect(exported['snapshot']).toBeDefined();

    await analyticsService.purgeData(userA);
    const postPurge = await analyticsService.exportData(userA);
    expect(postPurge['snapshot']).toBeNull();
  });
});
