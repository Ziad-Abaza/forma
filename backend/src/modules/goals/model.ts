/**
 * Goal Domain (ADR-009, §7.2)
 *
 * Rules:
 * - Versioned goals: Edits create versions so historical progress is evaluated against the goal as it was.
 * - Multi-type: weight loss, fat loss, muscle gain, maintenance, recomposition, measurement target.
 * - Primary goal designation for dashboard and default AI context.
 */

export type GoalType =
  | 'weight_loss'
  | 'fat_loss'
  | 'weight_gain'
  | 'muscle_gain'
  | 'recomposition'
  | 'maintenance'
  | 'measurement_target';

export type GoalStatus = 'active' | 'paused' | 'achieved' | 'abandoned';

export interface GoalVersion {
  version: number;
  targetMetricCode: string;
  targetCanonicalValue: number;
  targetCanonicalUnit: string;
  baselineCanonicalValue: number;
  weeklyRateTargetKg?: number;
  deadline?: string;
  createdAt: string;
  reasonForChange?: string;
}

export interface Goal {
  id: string;
  userId: string;
  type: GoalType;
  isPrimary: boolean;
  status: GoalStatus;
  currentVersion: number;
  versions: GoalVersion[];
  createdAt: string;
  updatedAt: string;
}

export class GoalService {
  /**
   * Create a new goal with version 1.
   */
  static createGoal(params: {
    id: string;
    userId: string;
    type: GoalType;
    isPrimary: boolean;
    targetMetricCode: string;
    targetCanonicalValue: number;
    targetCanonicalUnit: string;
    baselineCanonicalValue: number;
    weeklyRateTargetKg?: number;
    deadline?: string;
  }): Goal {
    const now = new Date().toISOString();
    const version1: GoalVersion = {
      version: 1,
      targetMetricCode: params.targetMetricCode,
      targetCanonicalValue: params.targetCanonicalValue,
      targetCanonicalUnit: params.targetCanonicalUnit,
      baselineCanonicalValue: params.baselineCanonicalValue,
      weeklyRateTargetKg: params.weeklyRateTargetKg,
      deadline: params.deadline,
      createdAt: now,
    };

    return {
      id: params.id,
      userId: params.userId,
      type: params.type,
      isPrimary: params.isPrimary,
      status: 'active',
      currentVersion: 1,
      versions: [version1],
      createdAt: now,
      updatedAt: now,
    };
  }

  /**
   * Evolve a goal by adding a new version.
   */
  static updateGoalVersion(
    current: Goal,
    updates: {
      targetCanonicalValue?: number;
      weeklyRateTargetKg?: number;
      deadline?: string;
      reasonForChange?: string;
    }
  ): Goal {
    const latestVersion = current.versions[current.versions.length - 1];
    const newVersionNum = current.currentVersion + 1;
    const now = new Date().toISOString();

    const newVersion: GoalVersion = {
      version: newVersionNum,
      targetMetricCode: latestVersion.targetMetricCode,
      targetCanonicalValue: updates.targetCanonicalValue ?? latestVersion.targetCanonicalValue,
      targetCanonicalUnit: latestVersion.targetCanonicalUnit,
      baselineCanonicalValue: latestVersion.baselineCanonicalValue,
      weeklyRateTargetKg: updates.weeklyRateTargetKg ?? latestVersion.weeklyRateTargetKg,
      deadline: updates.deadline ?? latestVersion.deadline,
      createdAt: now,
      reasonForChange: updates.reasonForChange,
    };

    return {
      ...current,
      currentVersion: newVersionNum,
      versions: [...current.versions, newVersion],
      updatedAt: now,
    };
  }

  /**
   * Calculate progress percentage against the goal version.
   */
  static evaluateProgress(goal: Goal, currentCanonicalValue: number): {
    progressPercentage: number;
    remaining: number;
    isAchieved: boolean;
  } {
    const activeVersion = goal.versions[goal.versions.length - 1];
    const baseline = activeVersion.baselineCanonicalValue;
    const target = activeVersion.targetCanonicalValue;

    const totalChangeNeeded = target - baseline;
    const currentChange = currentCanonicalValue - baseline;

    if (totalChangeNeeded === 0) {
      return { progressPercentage: 100, remaining: 0, isAchieved: true };
    }

    const pct = Math.round((currentChange / totalChangeNeeded) * 100);
    const remaining = Math.round(Math.abs(target - currentCanonicalValue) * 100) / 100;
    const isAchieved = (totalChangeNeeded < 0 && currentCanonicalValue <= target) ||
                       (totalChangeNeeded > 0 && currentCanonicalValue >= target);

    return {
      progressPercentage: Math.max(0, Math.min(pct, 100)),
      remaining,
      isAchieved,
    };
  }
}
