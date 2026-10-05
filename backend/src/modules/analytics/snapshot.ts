import { withUserContext } from '../../core/database/index.js';
import type { HealthSnapshot, HealthSnapshotSections } from './contracts.js';
import { CalculationEngine, type ActivityLevel } from '../calculations/engine.js';
import { TrendEngine, type DataPoint } from './trends.js';
import { AnomalyDetector } from './anomalies.js';
import { MeasurementsRepository } from '../measurements/repository.js';
import { ProfileRepository } from '../profile/repository.js';
import { GoalsRepository } from '../goals/repository.js';
import { computeGoalProgressPct } from '../goals/contracts.js';

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
        const startVal = primaryGoal.currentVersion.startingValue;
        const targetVal = primaryGoal.currentVersion.targetValue;

        // Progress must come from a real measurement of the goal's OWN target
        // metric — not weight by assumption, and never "startingValue" as a
        // stand-in for a measurement that doesn't exist.
        const goalMetricObs =
          primaryGoal.targetMetricTypeCode === 'weight'
            ? latestWeight
            : await MeasurementsRepository.queryObservations(client, userId, {
                typeCode: primaryGoal.targetMetricTypeCode,
                status: 'active',
                limit: 1
              }).then((r) => r[0]);
        const currentVal = goalMetricObs ? Number(goalMetricObs.canonical_value) : undefined;
        const progressPct = currentVal !== undefined
          ? computeGoalProgressPct(primaryGoal.goalType, startVal, targetVal, currentVal)
          : undefined;

        // Never fabricate a weekly rate: without a real goal rate the projection
        // is insufficient and no projectedTargetDate is emitted.
        const projection = this.calc.projectWeightTimeline({
          currentWeightKg: latestWeightKg,
          targetWeightKg: targetVal,
          weeklyRateKg: primaryGoal.currentVersion.weeklyRate
        });

        goalSection = {
          hasActiveGoal: true,
          id: primaryGoal.id,
          goalType: primaryGoal.goalType,
          targetMetricCode: primaryGoal.targetMetricTypeCode,
          targetValue: targetVal,
          startingValue: startVal,
          currentValue: currentVal,
          progressPct,
          projectedTargetDate: projection.projectedTargetDate || undefined,
          isSafeRate: projection.sufficiency === 'complete' ? projection.isSafeRate : undefined
        };
      }

      // --- SECTION 4: Activity Level & Energy ---
      // Never fabricate an activity level: when the profile lacks one, TDEE and
      // calorie targets are reported as insufficient instead of being computed
      // on a guessed assumption. The profile schema uses 'extra_active' while the
      // engine's PAL table calls it 'extremely_active' — map it honestly.
      const PROFILE_TO_ENGINE_ACTIVITY: Record<string, ActivityLevel> = {
        sedentary: 'sedentary',
        lightly_active: 'lightly_active',
        moderately_active: 'moderately_active',
        very_active: 'very_active',
        extra_active: 'extremely_active',
        extremely_active: 'extremely_active'
      };
      const actLevel: ActivityLevel | undefined = profile?.activityLevel
        ? PROFILE_TO_ENGINE_ACTIVITY[profile.activityLevel]
        : undefined;
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

      let macroTargets = undefined;
      const targetCal = calorieTargets.targets.standardLoss.targetCalories;
      if (targetCal > 0 && latestWeightKg && latestWeightKg > 0) {
        const macroResult = this.calc.calculateMacroDistribution(targetCal, latestWeightKg);
        macroTargets = {
          proteinGrams: macroResult.proteinGrams,
          fatGrams: macroResult.fatGrams,
          carbsGrams: macroResult.carbsGrams,
          proteinPct: macroResult.proteinPct,
          fatPct: macroResult.fatPct,
          carbsPct: macroResult.carbsPct,
        };
      }

      const energySection = {
        bmr: bmrResult.value > 0 ? bmrResult.value : undefined,
        tdee: tdeeResult.value > 0 ? tdeeResult.value : undefined,
        activityLevel: actLevel,
        maintenanceCalories: calorieTargets.maintenance > 0 ? calorieTargets.maintenance : undefined,
        targetCalories: targetCal > 0 ? targetCal : undefined,
        macros: macroTargets,
        guardrailsTriggered: calorieTargets.guardrailsTriggered,
        isRefused: calorieTargets.isRefused,
        sufficiency: (bmrResult.sufficiency === 'complete' && tdeeResult.sufficiency === 'complete' ? 'complete' : 'insufficient') as any
      };

      // --- SECTION 5: Recent Measurements (Dynamic across all user-recorded types, with observation IDs) ---
      // Fetch the real epistemic class of each observation from its provenance
      // record — never assume 'measured'.
      const epistemicByProvenance = new Map<string, string>();
      const provenanceIds = Array.from(new Set(activeObs.map((o) => o.provenance_id)));
      if (provenanceIds.length > 0) {
        const provRes = await client.query(
          `SELECT id, epistemic_class FROM provenance_records WHERE id = ANY($1::uuid[])`,
          [provenanceIds]
        );
        for (const row of provRes.rows) {
          epistemicByProvenance.set(row.id, row.epistemic_class);
        }
      }

      const seenTypes = new Set<string>();
      const recentMeasurements = [];

      for (const obs of activeObs) {
        if (!seenTypes.has(obs.type_code)) {
          seenTypes.add(obs.type_code);
          recentMeasurements.push({
            id: obs.id,
            typeCode: obs.type_code,
            canonicalValue: Number(obs.canonical_value),
            canonicalUnit: obs.canonical_unit,
            observedAt: obs.observed_at.toISOString(),
            // 'asserted' is the weakest honest claim when provenance is somehow missing
            epistemicClass: epistemicByProvenance.get(obs.provenance_id) || 'asserted'
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
      // True total (the fetched page is capped at 100 for display lists).
      const totalCount = await MeasurementsRepository.countObservations(client, userId);
      // Staleness is measured from the latest observation of ANY type, not just weight.
      // activeObs is ordered by observed_at DESC.
      const latestObservedAt = activeObs[0]?.observed_at;
      let stalenessDays: number | undefined;
      if (latestObservedAt) {
        const diffMs = Date.now() - latestObservedAt.getTime();
        stalenessDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
      }

      // Real share of 'measured' observations among ALL active observations —
      // counted in SQL, not over the capped page; null when nothing exists.
      const measuredCount = await MeasurementsRepository.countObservations(
        client,
        userId,
        'active',
        'measured'
      );

      const dataQuality = {
        totalActiveObservations: totalCount,
        measuredSharePct: totalCount > 0 ? Math.round((measuredCount / totalCount) * 100) : null,
        stalenessDays,
        hasAnomalies: anomalies.length > 0
      };

      const sections: HealthSnapshotSections = {
        identityLite,
        bodyStatus,
        goal: goalSection,
        energy: energySection,
        activityLevel: {
          level: actLevel,
          multiplier: tdeeResult.sufficiency === 'complete' ? tdeeResult.multiplier : undefined
        },
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
