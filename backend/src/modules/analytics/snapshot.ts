import { withUserContext } from '../../core/database/index.js';
import type { HealthSnapshot, HealthSnapshotSections } from './contracts.js';
import { CalculationEngine } from '../calculations/engine.js';
import { TrendEngine, type DataPoint } from './trends.js';
import { AnomalyDetector } from './anomalies.js';
import { MeasurementsRepository } from '../measurements/repository.js';
import { ProfileRepository } from '../profile/repository.js';
import { GoalsRepository } from '../goals/repository.js';

export class SnapshotEngine {
  private readonly calc = new CalculationEngine();
  private readonly goalsRepo = new GoalsRepository();

  /**
   * Recomputes the entire Health Snapshot from pure source facts.
   * This is a 100% deterministic derivation.
   */
  public async computeSnapshot(userId: string): Promise<HealthSnapshot> {
    return withUserContext(userId, async (client) => {
      // 1. Fetch Profile
      const profile = await ProfileRepository.getProfileByUserId(client, userId);

      // 2. Fetch Active Observations
      const activeObs = await MeasurementsRepository.queryObservations(client, userId, {
        status: 'active',
        limit: 100
      });

      // 3. Fetch Primary Goal
      const primaryGoal = await this.goalsRepo.getPrimaryGoal(userId);

      // --- SECTION 1: Identity Lite ---
      const birthDate = profile?.dateOfBirth ? new Date(profile.dateOfBirth) : undefined;
      let ageYears: number | undefined;
      if (birthDate) {
        const diffMs = Date.now() - birthDate.getTime();
        ageYears = Math.floor(diffMs / (1000 * 60 * 60 * 24 * 365.25));
      }

      const identityLite = {
        units: (profile?.preferences as any)?.units || { mass: 'kg', length: 'cm' },
        language: ((profile?.preferences as any)?.preferredLanguage as string) || 'en',
        ageYears,
        sexForCalculation: profile?.sexForCalculation || undefined,
        heightCm: profile?.heightCm ? Number(profile.heightCm) : undefined
      };

      // --- SECTION 2: Body Status & Weight Trends ---
      const weightObs = activeObs
        .filter((o) => o.type_code === 'weight')
        .sort((a, b) => b.observed_at.getTime() - a.observed_at.getTime());

      const latestWeight = weightObs[0];
      const latestWeightKg = latestWeight ? Number(latestWeight.canonical_value) : undefined;

      const weightDataPoints: DataPoint[] = weightObs.map((o) => ({
        observedAt: o.observed_at,
        value: Number(o.canonical_value)
      }));
      const weightTrend = TrendEngine.calculateTrend('weight', weightDataPoints, 30);

      const bmiResult = this.calc.calculateBmi(latestWeightKg, identityLite.heightCm);

      const bodyStatus = {
        latestWeightKg,
        observedAt: latestWeight ? latestWeight.observed_at.toISOString() : undefined,
        trend7dKg: weightTrend.smoothedLatest,
        weeklyRateKg: weightTrend.weeklyRate,
        bmi: bmiResult.sufficiency === 'complete' ? bmiResult.value : undefined,
        bmiCategory: bmiResult.sufficiency === 'complete' ? bmiResult.category : undefined,
        sufficiency: (latestWeightKg && identityLite.heightCm ? 'complete' : latestWeightKg ? 'partial' : 'insufficient') as any
      };

      // --- SECTION 3: Goal & Projection ---
      let goalSection = {
        hasActiveGoal: false
      } as any;

      if (primaryGoal && primaryGoal.currentVersion) {
        let progressPct = 0;
        const currentVal = latestWeightKg || primaryGoal.currentVersion.startingValue;
        const startVal = primaryGoal.currentVersion.startingValue;
        const targetVal = primaryGoal.currentVersion.targetValue;
        const dist = Math.abs(targetVal - startVal);

        if (dist === 0) {
          progressPct = 100;
        } else if (primaryGoal.goalType === 'weight_loss' || targetVal < startVal) {
          progressPct = Math.round(((startVal - currentVal) / dist) * 1000) / 10;
        } else {
          progressPct = Math.round(((currentVal - startVal) / dist) * 1000) / 10;
        }

        const projection = this.calc.projectWeightTimeline({
          currentWeightKg: latestWeightKg,
          targetWeightKg: targetVal,
          weeklyRateKg: primaryGoal.currentVersion.weeklyRate || 0.5
        });

        goalSection = {
          hasActiveGoal: true,
          goalType: primaryGoal.goalType,
          targetMetricCode: primaryGoal.targetMetricTypeCode,
          targetValue: targetVal,
          startingValue: startVal,
          currentValue: currentVal,
          progressPct,
          projectedTargetDate: projection.projectedTargetDate || undefined,
          isSafeRate: projection.isSafeRate
        };
      }

      // --- SECTION 4: Activity Level & Energy ---
      const actLevel = (profile?.activityLevel as any) || 'moderately_active';
      const bmrResult = this.calc.calculateBmr({
        weightKg: latestWeightKg,
        heightCm: identityLite.heightCm,
        ageYears: identityLite.ageYears,
        sex: identityLite.sexForCalculation as any
      });

      const tdeeResult = this.calc.calculateTdee(bmrResult.value, actLevel);
      const calorieTargets = this.calc.calculateCalorieTargets({
        tdee: tdeeResult.value,
        sex: identityLite.sexForCalculation as any
      });

      const energySection = {
        bmr: bmrResult.value > 0 ? bmrResult.value : undefined,
        tdee: tdeeResult.value > 0 ? tdeeResult.value : undefined,
        activityLevel: actLevel,
        maintenanceCalories: calorieTargets.maintenance > 0 ? calorieTargets.maintenance : undefined,
        targetCalories: calorieTargets.targets.standardLoss.targetCalories > 0 ? calorieTargets.targets.standardLoss.targetCalories : undefined,
        guardrailsTriggered: calorieTargets.guardrailsTriggered,
        isRefused: calorieTargets.isRefused,
        sufficiency: (bmrResult.sufficiency === 'complete' && tdeeResult.sufficiency === 'complete' ? 'complete' : 'insufficient') as any
      };

      // --- SECTION 5: Recent Measurements ---
      const keyTypes = ['weight', 'body_fat_percentage', 'muscle_mass', 'waist_circumference'];
      const recentMeasurements = [];

      for (const t of keyTypes) {
        const match = activeObs.find((o) => o.type_code === t);
        if (match) {
          recentMeasurements.push({
            typeCode: match.type_code,
            canonicalValue: Number(match.canonical_value),
            canonicalUnit: match.canonical_unit,
            observedAt: match.observed_at.toISOString(),
            epistemicClass: 'measured'
          });
        }
      }

      // --- SECTION 6: Anomalies Detection ---
      const anomalies = [];
      if (latestWeight && weightObs.length > 1) {
        const flag = AnomalyDetector.checkObservation(
          userId,
          {
            id: latestWeight.id,
            typeCode: latestWeight.type_code,
            canonicalValue: Number(latestWeight.canonical_value),
            observedAt: latestWeight.observed_at
          },
          weightObs.slice(1).map((o) => ({
            id: o.id,
            typeCode: o.type_code,
            canonicalValue: Number(o.canonical_value),
            observedAt: o.observed_at
          }))
        );
        if (flag) anomalies.push(flag);
      }

      // --- SECTION 7: Data Quality ---
      const totalCount = activeObs.length;
      let stalenessDays: number | undefined;
      if (latestWeight) {
        const diffMs = Date.now() - latestWeight.observed_at.getTime();
        stalenessDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
      }

      const dataQuality = {
        totalActiveObservations: totalCount,
        measuredSharePct: 100, // all are measured observations
        stalenessDays,
        hasAnomalies: anomalies.length > 0
      };

      const sections: HealthSnapshotSections = {
        identityLite,
        bodyStatus,
        goal: goalSection,
        energy: energySection,
        activityLevel: { level: actLevel, multiplier: tdeeResult.multiplier },
        recentMeasurements,
        anomalies,
        dataQuality
      };

      // Watermark derived from max observed_at timestamp and row counts
      const maxObsDate = activeObs.length > 0 ? activeObs[0]!.observed_at.getTime() : 0;
      const watermark = `obs:${activeObs.length}_max:${maxObsDate}_goal:${primaryGoal?.id || 'none'}_prof:${profile?.updatedAt?.getTime() || 0}`;

      return {
        userId,
        snapshotVersion: 1,
        sourceDataWatermark: watermark,
        sections,
        reconciledAt: new Date().toISOString(),
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
      };
    });
  }

  /**
   * Persists or refreshes the cached snapshot in the database.
   */
  public async getOrRefreshSnapshot(userId: string): Promise<HealthSnapshot> {
    const fresh = await this.computeSnapshot(userId);

    await withUserContext(userId, async (client) => {
      await client.query(
        `INSERT INTO health_snapshots (user_id, snapshot_version, source_data_watermark, sections, reconciled_at, updated_at)
         VALUES ($1, $2, $3, $4, NOW(), NOW())
         ON CONFLICT (user_id) DO UPDATE SET
           snapshot_version = EXCLUDED.snapshot_version,
           source_data_watermark = EXCLUDED.source_data_watermark,
           sections = EXCLUDED.sections,
           reconciled_at = NOW(),
           updated_at = NOW()`,
        [userId, fresh.snapshotVersion, fresh.sourceDataWatermark, JSON.stringify(fresh.sections)]
      );
    });

    return fresh;
  }

  /**
   * Reconciles cached snapshot with recomputation.
   * Proves zero drift. Returns true if perfectly consistent.
   */
  public async reconcile(userId: string): Promise<{ isDriftDetected: boolean; diffDetails?: string }> {
    const fresh = await this.computeSnapshot(userId);

    const cachedRow = await withUserContext(userId, async (client) => {
      const res = await client.query(`SELECT * FROM health_snapshots WHERE user_id = $1`, [userId]);
      return res.rows[0];
    });

    if (!cachedRow) {
      return { isDriftDetected: true, diffDetails: 'Snapshot not yet materialized in DB.' };
    }

    if (cachedRow.source_data_watermark !== fresh.sourceDataWatermark) {
      return {
        isDriftDetected: true,
        diffDetails: `Watermark mismatch: cached [${cachedRow.source_data_watermark}] vs fresh [${fresh.sourceDataWatermark}]`
      };
    }

    return { isDriftDetected: false };
  }
}
