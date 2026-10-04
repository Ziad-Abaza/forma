/**
 * Profile Domain (ADR-009, §7.2)
 *
 * Rules:
 * - Stable core attributes for deterministic calculations: height, sex-for-calculation, DOB, activity level.
 * - History versioning: Calculation-relevant changes are time-versioned so past calculations remain reproducible.
 * - Profile Attribute (extensible): Key-value extensions without modifying core structures.
 */

export type SexForCalculation = 'male' | 'female' | 'prefer_not_to_say';
export type ActivityLevel = 'sedentary' | 'lightly_active' | 'moderately_active' | 'very_active' | 'extra_active';

export interface CalculationProfileSnapshot {
  version: number;
  heightCm: number;
  sexForCalculation: SexForCalculation;
  dateOfBirth: string;
  activityLevel: ActivityLevel;
  effectiveFrom: string;
}

export interface UserProfile {
  userId: string;
  heightCm: number;
  sexForCalculation: SexForCalculation;
  dateOfBirth: string;
  activityLevel: ActivityLevel;
  preferredLanguage: 'en' | 'ar';
  preferredNumeralSystem: 'western' | 'eastern_arabic';
  preferredUnits: {
    mass: string;
    length: string;
    energy: string;
  };
  attributes: Record<string, string | number | boolean | string[]>;
  calculationSnapshots: CalculationProfileSnapshot[];
  updatedAt: string;
}

export class ProfileService {
  /**
   * Create or update profile with calculation versioning.
   */
  static updateCalculationAttributes(
    current: UserProfile,
    updates: {
      heightCm?: number;
      sexForCalculation?: SexForCalculation;
      activityLevel?: ActivityLevel;
    }
  ): UserProfile {
    const hasChanged =
      (updates.heightCm !== undefined && updates.heightCm !== current.heightCm) ||
      (updates.sexForCalculation !== undefined && updates.sexForCalculation !== current.sexForCalculation) ||
      (updates.activityLevel !== undefined && updates.activityLevel !== current.activityLevel);

    const now = new Date().toISOString();
    const newHeight = updates.heightCm ?? current.heightCm;
    const newSex = updates.sexForCalculation ?? current.sexForCalculation;
    const newActivity = updates.activityLevel ?? current.activityLevel;

    const snapshots = [...current.calculationSnapshots];
    if (hasChanged) {
      snapshots.push({
        version: snapshots.length + 1,
        heightCm: newHeight,
        sexForCalculation: newSex,
        dateOfBirth: current.dateOfBirth,
        activityLevel: newActivity,
        effectiveFrom: now,
      });
    }

    return {
      ...current,
      heightCm: newHeight,
      sexForCalculation: newSex,
      activityLevel: newActivity,
      calculationSnapshots: snapshots,
      updatedAt: now,
    };
  }
}
