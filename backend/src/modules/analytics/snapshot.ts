/**
 * Health Snapshot Engine (ADR-019, §7.8)
 *
 * Rules:
 * - Materialized composition of current state (Profile, Body Status, Goal, Energy, Anomalies).
 * - Read model only, never a source of truth.
 * - Each section carries layer label, provenance/confidence, as-of time, and source watermark.
 * - Invalidation: granular per-section invalidation on source changes (ADR-024).
 * - Drift reconciliation: compare snapshot vs fresh recomputation.
 */

import { UserProfile } from '../profile/model.js';
import { Observation } from '../measurements/model.js';
import { Goal, GoalService } from '../goals/model.js';
import { CalculationEngine } from '../calculations/engine.js';
import { AnalyticsService } from './service.js';

export interface HealthSnapshotSection<T> {
  asOf: string;
  sourceWatermark: string;
  dataSufficiency: 'complete' | 'partial' | 'insufficient';
  data: T;
}

export interface HealthSnapshot {
  userId: string;
  version: number;
  generatedAt: string;
  sections: {
    identityLite: HealthSnapshotSection<{
      ageYears: number;
      heightCm: number;
      sexForCalculation: string;
      preferredUnits: Record<string, string>;
      preferredLanguage: string;
    }>;
    bodyStatus: HealthSnapshotSection<{
      latestWeightKg?: number;
      weightTrendRatePerWeek?: number;
      bodyFatPct?: number;
      leanMassKg?: number;
    }>;
    primaryGoal?: HealthSnapshotSection<{
      goalId: string;
      type: string;
      targetValue: number;
      baselineValue: number;
      currentValue: number;
      progressPercentage: number;
      isAchieved: boolean;
    }>;
    energy: HealthSnapshotSection<{
      bmrKcal: number;
      tdeeKcal: number;
      targetCalories: number;
      proteinGrams: number;
      fatGrams: number;
      carbGrams: number;
    }>;
    anomalies: HealthSnapshotSection<Array<{
      date: string;
      value: number;
      reason: string;
    }>>;
  };
}

export class SnapshotEngine {
  /**
   * Compute full Health Snapshot from source records.
   */
  static generateSnapshot(params: {
    profile: UserProfile;
    observations: Observation[];
    goals: Goal[];
  }): HealthSnapshot {
    const now = new Date().toISOString();
    const watermark = `wm_${Date.now()}`;

    // 1. Calculate Age
    const dob = new Date(params.profile.dateOfBirth);
    const today = new Date();
    let ageYears = today.getFullYear() - dob.getFullYear();
    const m = today.getMonth() - dob.getMonth();
    if (m < 0 || (m === 0 && today.getDate() < dob.getDate())) {
      ageYears--;
    }

    // 2. Identity Lite section
    const identityLite: HealthSnapshotSection<any> = {
      asOf: now,
      sourceWatermark: watermark,
      dataSufficiency: 'complete',
      data: {
        ageYears,
        heightCm: params.profile.heightCm,
        sexForCalculation: params.profile.sexForCalculation,
        preferredUnits: params.profile.preferredUnits,
        preferredLanguage: params.profile.preferredLanguage,
      },
    };

    // 3. Body Status section
    const weightObs = params.observations.filter((o) => o.typeCode === 'weight');
    const fatObs = params.observations.filter((o) => o.typeCode === 'body_fat_pct');
    const leanObs = params.observations.filter((o) => o.typeCode === 'lean_mass');

    const weightTrend = AnalyticsService.analyzeTrend(weightObs);
    const latestFat = fatObs.length > 0 ? fatObs[fatObs.length - 1].canonicalValue : undefined;
    const latestLean = leanObs.length > 0 ? leanObs[leanObs.length - 1].canonicalValue : undefined;

    const bodyStatus: HealthSnapshotSection<any> = {
      asOf: now,
      sourceWatermark: watermark,
      dataSufficiency: weightObs.length > 0 ? 'complete' : 'insufficient',
      data: {
        latestWeightKg: weightTrend.latestValue || undefined,
        weightTrendRatePerWeek: weightTrend.rateOfChangePerWeek,
        bodyFatPct: latestFat,
        leanMassKg: latestLean,
      },
    };

    // 4. Primary Goal section
    const primaryGoal = params.goals.find((g) => g.isPrimary && g.status === 'active');
    let primaryGoalSection: HealthSnapshotSection<any> | undefined;

    if (primaryGoal) {
      const currentVal = weightTrend.latestValue || 0;
      const progress = GoalService.evaluateProgress(primaryGoal, currentVal);
      const activeVersion = primaryGoal.versions[primaryGoal.versions.length - 1];

      primaryGoalSection = {
        asOf: now,
        sourceWatermark: watermark,
        dataSufficiency: currentVal > 0 ? 'complete' : 'partial',
        data: {
          goalId: primaryGoal.id,
          type: primaryGoal.type,
          targetValue: activeVersion.targetCanonicalValue,
          baselineValue: activeVersion.baselineCanonicalValue,
          currentValue: currentVal,
          progressPercentage: progress.progressPercentage,
          isAchieved: progress.isAchieved,
        },
      };
    }

    // 5. Energy section via CalculationEngine
    const bmrRes = CalculationEngine.calculateBmr({
      weightKg: bodyStatus.data.latestWeightKg,
      heightCm: params.profile.heightCm,
      ageYears,
      sex: params.profile.sexForCalculation,
      leanMassKg: bodyStatus.data.leanMassKg,
    });

    const tdeeRes = CalculationEngine.calculateTdee({
      bmrKcal: bmrRes.value.bmrKcal,
      activityLevel: params.profile.activityLevel,
    });

    const targetRes = CalculationEngine.calculateCalorieTarget({
      tdeeKcal: tdeeRes.value.tdeeKcal,
      goalType: (primaryGoal?.type as any) || 'maintenance',
      sex: params.profile.sexForCalculation,
    });

    const macroRes = CalculationEngine.calculateMacros({
      targetCalories: targetRes.value.targetCalories,
      weightKg: bodyStatus.data.latestWeightKg || 70,
      goalType: (primaryGoal?.type as any) || 'maintenance',
    });

    const energy: HealthSnapshotSection<any> = {
      asOf: now,
      sourceWatermark: watermark,
      dataSufficiency: bmrRes.dataSufficiency,
      data: {
        bmrKcal: bmrRes.value.bmrKcal,
        tdeeKcal: tdeeRes.value.tdeeKcal,
        targetCalories: targetRes.value.targetCalories,
        proteinGrams: macroRes.value.proteinGrams,
        fatGrams: macroRes.value.fatGrams,
        carbGrams: macroRes.value.carbGrams,
      },
    };

    // 6. Anomalies section
    const anomalies: HealthSnapshotSection<any> = {
      asOf: now,
      sourceWatermark: watermark,
      dataSufficiency: 'complete',
      data: weightTrend.anomalies,
    };

    return {
      userId: params.profile.userId,
      version: 1,
      generatedAt: now,
      sections: {
        identityLite,
        bodyStatus,
        primaryGoal: primaryGoalSection,
        energy,
        anomalies,
      },
    };
  }

  /**
   * Reconcile snapshot against fresh calculation to detect drift (§7.8 rule 6).
   */
  static reconcile(cached: HealthSnapshot, fresh: HealthSnapshot): {
    hasDrift: boolean;
    driftFields: string[];
  } {
    const driftFields: string[] = [];
    if (cached.sections.energy.data.targetCalories !== fresh.sections.energy.data.targetCalories) {
      driftFields.push('energy.targetCalories');
    }
    if (cached.sections.bodyStatus.data.latestWeightKg !== fresh.sections.bodyStatus.data.latestWeightKg) {
      driftFields.push('bodyStatus.latestWeightKg');
    }
    return {
      hasDrift: driftFields.length > 0,
      driftFields,
    };
  }
}
