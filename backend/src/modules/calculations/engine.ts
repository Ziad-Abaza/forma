/**
 * Deterministic Calculation Engine (ADR-010, §15)
 *
 * Rules:
 * - Versioned formulas: Each formula has an explicit ID and version.
 * - Pure and testable: Same inputs -> same outputs.
 * - Data sufficiency: Explicit inputs, assumptions, and sufficiency status.
 * - Safety guardrails: Calorie floors, max loss/gain rates, adolescent/medical cautions.
 * - Calculations are never delegated to the LLM.
 */

export interface CalculationResult<T> {
  formulaId: string;
  formulaVersion: string;
  value: T;
  inputsUsed: Record<string, unknown>;
  assumptions: string[];
  dataSufficiency: 'complete' | 'partial' | 'insufficient';
  missingInputs?: string[];
  safetyFlags: string[];
  computedAt: string;
}

export const FORMULA_VERSIONS = {
  BMI: '1.0.0',
  BMR_MIFFLIN_ST_JEOR: '1.0.0',
  BMR_KATCH_MCARDLE: '1.0.0',
  TDEE: '1.0.0',
  CALORIE_TARGETS: '1.0.0',
  MACRO_SPLIT: '1.0.0',
};

// Activity multipliers according to standard exercise science
export const ACTIVITY_MULTIPLIERS = {
  sedentary: 1.2,
  lightly_active: 1.375,
  moderately_active: 1.55,
  very_active: 1.725,
  extra_active: 1.9,
};

// Health Safety Guardrails (ADR-010, §10.6, §15.5)
export const SAFETY_GUARDRAILS = {
  MIN_CALORIE_FLOOR_MALE: 1500,
  MIN_CALORIE_FLOOR_FEMALE: 1200,
  MIN_CALORIE_FLOOR_GENERAL: 1200,
  MAX_SAFE_WEIGHT_LOSS_KG_PER_WEEK: 1.0, // ~1% body weight or max 1 kg/week
  MAX_SAFE_WEIGHT_GAIN_KG_PER_WEEK: 0.5,
  MAX_DEFICIT_KCAL: 1000,
  MAX_SURPLUS_KCAL: 500,
};

export class CalculationEngine {
  /**
   * Calculate BMI: weight(kg) / (height(m))^2
   */
  static calculateBmi(params: {
    weightKg?: number;
    heightCm?: number;
  }): CalculationResult<{ bmi: number; classification: string }> {
    const missing: string[] = [];
    if (!params.weightKg) missing.push('weightKg');
    if (!params.heightCm) missing.push('heightCm');

    if (missing.length > 0) {
      return {
        formulaId: 'BMI',
        formulaVersion: FORMULA_VERSIONS.BMI,
        value: { bmi: 0, classification: 'unknown' },
        inputsUsed: params,
        assumptions: [],
        dataSufficiency: 'insufficient',
        missingInputs: missing,
        safetyFlags: ['insufficient_data'],
        computedAt: new Date().toISOString(),
      };
    }

    const heightM = params.heightCm! / 100.0;
    const bmi = Math.round((params.weightKg! / (heightM * heightM)) * 10) / 10;

    let classification = 'normal_weight';
    const safetyFlags: string[] = [];

    if (bmi < 18.5) {
      classification = 'underweight';
      safetyFlags.push('bmi_underweight_caution');
    } else if (bmi < 25.0) {
      classification = 'normal_weight';
    } else if (bmi < 30.0) {
      classification = 'overweight';
    } else {
      classification = 'obesity';
      if (bmi >= 35.0) {
        safetyFlags.push('bmi_high_obesity_caution');
      }
    }

    return {
      formulaId: 'BMI',
      formulaVersion: FORMULA_VERSIONS.BMI,
      value: { bmi, classification },
      inputsUsed: { weightKg: params.weightKg, heightCm: params.heightCm },
      assumptions: ['Standard WHO adult BMI cutoffs apply'],
      dataSufficiency: 'complete',
      safetyFlags,
      computedAt: new Date().toISOString(),
    };
  }

  /**
   * Calculate BMR using Mifflin-St Jeor (or Katch-McArdle if lean mass available)
   */
  static calculateBmr(params: {
    weightKg?: number;
    heightCm?: number;
    ageYears?: number;
    sex?: 'male' | 'female' | 'prefer_not_to_say';
    leanMassKg?: number;
  }): CalculationResult<{ bmrKcal: number; formulaUsed: string }> {
    // If lean mass is provided, prefer Katch-McArdle (most accurate for body composition)
    if (params.leanMassKg && params.leanMassKg > 0) {
      const bmr = Math.round(370 + 21.6 * params.leanMassKg);
      return {
        formulaId: 'BMR_KATCH_MCARDLE',
        formulaVersion: FORMULA_VERSIONS.BMR_KATCH_MCARDLE,
        value: { bmrKcal: bmr, formulaUsed: 'Katch-McArdle (Lean Mass Derived)' },
        inputsUsed: { leanMassKg: params.leanMassKg },
        assumptions: ['Lean body mass is measured reliably'],
        dataSufficiency: 'complete',
        safetyFlags: [],
        computedAt: new Date().toISOString(),
      };
    }

    const missing: string[] = [];
    if (!params.weightKg) missing.push('weightKg');
    if (!params.heightCm) missing.push('heightCm');
    if (!params.ageYears) missing.push('ageYears');

    if (missing.length > 0) {
      return {
        formulaId: 'BMR_MIFFLIN_ST_JEOR',
        formulaVersion: FORMULA_VERSIONS.BMR_MIFFLIN_ST_JEOR,
        value: { bmrKcal: 0, formulaUsed: 'None' },
        inputsUsed: params,
        assumptions: [],
        dataSufficiency: 'insufficient',
        missingInputs: missing,
        safetyFlags: ['insufficient_data'],
        computedAt: new Date().toISOString(),
      };
    }

    // Mifflin-St Jeor
    // Male: (10 × weight) + (6.25 × height) - (5 × age) + 5
    // Female: (10 × weight) + (6.25 × height) - (5 × age) - 161
    // Fallback if sex not specified: neutral average (-78)
    let sOffset = -78;
    const assumptions = ['Mifflin-St Jeor predictive formula used'];

    if (params.sex === 'male') {
      sOffset = 5;
    } else if (params.sex === 'female') {
      sOffset = -161;
    } else {
      assumptions.push('Sex not specified: applied gender-neutral midpoint calculation');
    }

    const bmr = Math.round(10 * params.weightKg! + 6.25 * params.heightCm! - 5 * params.ageYears! + sOffset);

    return {
      formulaId: 'BMR_MIFFLIN_ST_JEOR',
      formulaVersion: FORMULA_VERSIONS.BMR_MIFFLIN_ST_JEOR,
      value: { bmrKcal: bmr, formulaUsed: 'Mifflin-St Jeor' },
      inputsUsed: {
        weightKg: params.weightKg,
        heightCm: params.heightCm,
        ageYears: params.ageYears,
        sex: params.sex,
      },
      assumptions,
      dataSufficiency: params.sex === 'prefer_not_to_say' ? 'partial' : 'complete',
      safetyFlags: [],
      computedAt: new Date().toISOString(),
    };
  }

  /**
   * Calculate TDEE (Total Daily Energy Expenditure)
   */
  static calculateTdee(params: {
    bmrKcal: number;
    activityLevel: keyof typeof ACTIVITY_MULTIPLIERS;
  }): CalculationResult<{ tdeeKcal: number; multiplier: number }> {
    const multiplier = ACTIVITY_MULTIPLIERS[params.activityLevel] || 1.2;
    const tdee = Math.round(params.bmrKcal * multiplier);

    return {
      formulaId: 'TDEE',
      formulaVersion: FORMULA_VERSIONS.TDEE,
      value: { tdeeKcal: tdee, multiplier },
      inputsUsed: params,
      assumptions: [`Activity multiplier ${multiplier} for '${params.activityLevel}'`],
      dataSufficiency: 'complete',
      safetyFlags: [],
      computedAt: new Date().toISOString(),
    };
  }

  /**
   * Calculate Calorie Target with hard safety guardrails (ADR-010, §15.5)
   */
  static calculateCalorieTarget(params: {
    tdeeKcal: number;
    goalType: 'fat_loss' | 'weight_loss' | 'muscle_gain' | 'weight_gain' | 'maintenance' | 'recomposition';
    rateKgPerWeek?: number;
    sex?: 'male' | 'female' | 'prefer_not_to_say';
  }): CalculationResult<{
    targetCalories: number;
    deltaKcal: number;
    safeRateKgPerWeek: number;
    guardrailClamped: boolean;
  }> {
    const safetyFlags: string[] = [];
    let delta = 0;
    let safeRate = 0;
    let guardrailClamped = false;

    // 1 kg fat mass ≈ 7700 kcal -> ~1100 kcal deficit/day for 1kg/week
    const KCAL_PER_KG_FAT = 7700;

    if (params.goalType === 'fat_loss' || params.goalType === 'weight_loss') {
      const requestedRate = params.rateKgPerWeek ?? 0.5; // default 0.5 kg/week
      safeRate = Math.min(requestedRate, SAFETY_GUARDRAILS.MAX_SAFE_WEIGHT_LOSS_KG_PER_WEEK);
      if (requestedRate > SAFETY_GUARDRAILS.MAX_SAFE_WEIGHT_LOSS_KG_PER_WEEK) {
        safetyFlags.push('excessive_loss_rate_clamped');
        guardrailClamped = true;
      }

      delta = -Math.round((safeRate * KCAL_PER_KG_FAT) / 7);
      if (Math.abs(delta) > SAFETY_GUARDRAILS.MAX_DEFICIT_KCAL) {
        delta = -SAFETY_GUARDRAILS.MAX_DEFICIT_KCAL;
        guardrailClamped = true;
        safetyFlags.push('max_deficit_clamped');
      }
    } else if (params.goalType === 'muscle_gain' || params.goalType === 'weight_gain') {
      const requestedRate = params.rateKgPerWeek ?? 0.25;
      safeRate = Math.min(requestedRate, SAFETY_GUARDRAILS.MAX_SAFE_WEIGHT_GAIN_KG_PER_WEEK);
      if (requestedRate > SAFETY_GUARDRAILS.MAX_SAFE_WEIGHT_GAIN_KG_PER_WEEK) {
        safetyFlags.push('excessive_gain_rate_clamped');
        guardrailClamped = true;
      }
      // Lean tissue growth requires ~300-500 kcal surplus
      delta = Math.min(Math.round((safeRate * 5000) / 7), SAFETY_GUARDRAILS.MAX_SURPLUS_KCAL);
    } else {
      // Maintenance or recomposition
      delta = 0;
      safeRate = 0;
    }

    let targetCalories = params.tdeeKcal + delta;

    // Apply absolute minimum calorie floor
    const floor =
      params.sex === 'male'
        ? SAFETY_GUARDRAILS.MIN_CALORIE_FLOOR_MALE
        : params.sex === 'female'
        ? SAFETY_GUARDRAILS.MIN_CALORIE_FLOOR_FEMALE
        : SAFETY_GUARDRAILS.MIN_CALORIE_FLOOR_GENERAL;

    if (targetCalories < floor) {
      targetCalories = floor;
      guardrailClamped = true;
      safetyFlags.push(`calorie_floor_enforced: minimum ${floor} kcal`);
    }

    return {
      formulaId: 'CALORIE_TARGETS',
      formulaVersion: FORMULA_VERSIONS.CALORIE_TARGETS,
      value: {
        targetCalories,
        deltaKcal: delta,
        safeRateKgPerWeek: safeRate,
        guardrailClamped,
      },
      inputsUsed: params,
      assumptions: ['7700 kcal per kg adipose tissue loss model'],
      dataSufficiency: 'complete',
      safetyFlags,
      computedAt: new Date().toISOString(),
    };
  }

  /**
   * Calculate Macronutrient distribution based on bodyweight and calorie target
   */
  static calculateMacros(params: {
    targetCalories: number;
    weightKg: number;
    goalType: 'fat_loss' | 'weight_loss' | 'muscle_gain' | 'weight_gain' | 'maintenance' | 'recomposition';
  }): CalculationResult<{
    proteinGrams: number;
    fatGrams: number;
    carbGrams: number;
    proteinCalories: number;
    fatCalories: number;
    carbCalories: number;
  }> {
    // Evidence-based fitness targets:
    // Protein: 1.8g - 2.2g per kg bodyweight
    let proteinGramsPerKg = 2.0;
    if (params.goalType === 'fat_loss' || params.goalType === 'recomposition') {
      proteinGramsPerKg = 2.2; // higher protein for muscle sparing in deficit
    } else if (params.goalType === 'muscle_gain') {
      proteinGramsPerKg = 1.8;
    }

    const proteinG = Math.round(params.weightKg * proteinGramsPerKg);
    const proteinKcal = proteinG * 4;

    // Dietary Fat: ~0.8g - 1.0g per kg bodyweight (minimum ~20-25% of calories for hormonal health)
    const minFatKcal = Math.round(params.targetCalories * 0.25);
    const fatG = Math.round(minFatKcal / 9);
    const fatKcal = fatG * 9;

    // Remaining calories to Carbohydrates
    const remainingKcal = Math.max(0, params.targetCalories - (proteinKcal + fatKcal));
    const carbG = Math.round(remainingKcal / 4);
    const carbKcal = carbG * 4;

    return {
      formulaId: 'MACRO_SPLIT',
      formulaVersion: FORMULA_VERSIONS.MACRO_SPLIT,
      value: {
        proteinGrams: proteinG,
        fatGrams: fatG,
        carbGrams: carbG,
        proteinCalories: proteinKcal,
        fatCalories: fatKcal,
        carbCalories: carbKcal,
      },
      inputsUsed: params,
      assumptions: [
        `${proteinGramsPerKg}g protein per kg bodyweight`,
        '25% of calories allocated to dietary fats for hormonal health',
        'Remaining energy balance to carbohydrates',
      ],
      dataSufficiency: 'complete',
      safetyFlags: [],
      computedAt: new Date().toISOString(),
    };
  }
}
