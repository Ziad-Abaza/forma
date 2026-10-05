/**
 * Deterministic Calculation Engine
 * Strictly follows Blueprint §11, §15, and agent.md §2.4.
 *
 * Invariants:
 * 1. Deterministic and pure: same inputs -> exact same outputs.
 * 2. Versioned formulas with formula IDs & versions.
 * 3. Never delegated to an LLM.
 * 4. Units explicit: all computations are on canonical units (kg, cm, kcal).
 * 5. Returns data sufficiency status ('complete' | 'partial' | 'insufficient') with missing items enumerated.
 * 6. Hard safety guardrails enforced in code (calorie floors, maximum weekly rates, special population flags).
 */

export interface BmiResult {
  formulaId: 'bmi_who_v1';
  value: number; // kg/m^2 rounded to 1 decimal place
  category: 'underweight' | 'normal' | 'overweight' | 'obese_class_1' | 'obese_class_2' | 'obese_class_3';
  sufficiency: 'complete' | 'insufficient';
  missingInputs?: string[] | undefined;
}

export interface BmrResult {
  formulaId: 'bmr_mifflin_v1' | 'bmr_katch_mcardle_v1';
  value: number; // kcal/day rounded to integer
  sufficiency: 'complete' | 'insufficient';
  missingInputs?: string[] | undefined;
  method: 'mifflin_st_jeor' | 'katch_mcardle';
}

export type ActivityLevel = 'sedentary' | 'lightly_active' | 'moderately_active' | 'very_active' | 'extremely_active';

export interface TdeeResult {
  formulaId: 'tdee_pal_v1';
  value: number; // kcal/day rounded to integer
  bmr: number;
  activityLevel: ActivityLevel;
  multiplier: number;
  sufficiency: 'complete' | 'insufficient';
  missingInputs?: string[] | undefined;
}

export interface CalorieTargetsResult {
  formulaId: 'calorie_targets_v1';
  maintenance: number;
  targets: {
    moderateLoss: { targetCalories: number; weeklyDeficitKcal: number; expectedRateKgPerWeek: number };
    standardLoss: { targetCalories: number; weeklyDeficitKcal: number; expectedRateKgPerWeek: number };
    maintenance: { targetCalories: number; weeklyDeficitKcal: 0; expectedRateKgPerWeek: 0 };
    moderateGain: { targetCalories: number; weeklySurplusKcal: number; expectedRateKgPerWeek: number };
  };
  guardrailsTriggered: string[];
  isRefused: boolean;
  refusalReason?: string | undefined;
  sufficiency: 'complete' | 'insufficient';
  missingInputs?: string[] | undefined;
}

export interface MacroTargetsResult {
  formulaId: 'macro_distribution_v1';
  targetCalories: number;
  proteinGrams: number;
  proteinKcal: number;
  proteinPct: number;
  fatGrams: number;
  fatKcal: number;
  fatPct: number;
  carbsGrams: number;
  carbsKcal: number;
  carbsPct: number;
  sufficiency: 'complete';
}

export interface WeightTimelineProjection {
  formulaId: 'weight_timeline_v1';
  currentWeightKg: number;
  targetWeightKg: number;
  deltaKg: number;
  weeklyRateKg: number;
  estimatedWeeks: number;
  projectedTargetDate: string; // ISO date string (YYYY-MM-DD)
  isSafeRate: boolean;
  guardrailWarning?: string | undefined;
  sufficiency: 'complete' | 'insufficient';
  missingInputs?: string[] | undefined;
}

export class CalculationEngine {
  /**
   * Calculate Body Mass Index (BMI) using WHO criteria.
   * Formula: weight_kg / (height_m ^ 2)
   */
  public calculateBmi(weightKg?: number, heightCm?: number): BmiResult {
    const missing: string[] = [];
    if (weightKg === undefined || weightKg <= 0) missing.push('weight_kg');
    if (heightCm === undefined || heightCm <= 0) missing.push('height_cm');

    if (missing.length > 0 || !weightKg || !heightCm) {
      return {
        formulaId: 'bmi_who_v1',
        value: 0,
        category: 'normal',
        sufficiency: 'insufficient',
        missingInputs: missing
      };
    }

    const heightM = heightCm / 100.0;
    const rawBmi = weightKg / (heightM * heightM);
    const value = Math.round(rawBmi * 10) / 10;

    let category: BmiResult['category'] = 'normal';
    if (value < 18.5) category = 'underweight';
    else if (value < 25.0) category = 'normal';
    else if (value < 30.0) category = 'overweight';
    else if (value < 35.0) category = 'obese_class_1';
    else if (value < 40.0) category = 'obese_class_2';
    else category = 'obese_class_3';

    return {
      formulaId: 'bmi_who_v1',
      value,
      category,
      sufficiency: 'complete'
    };
  }

  /**
   * Calculate Basal Metabolic Rate (BMR).
   * Uses Katch-McArdle if lean body mass is known; otherwise Mifflin-St Jeor.
   */
  public calculateBmr(params: {
    weightKg?: number | undefined;
    heightCm?: number | undefined;
    ageYears?: number | undefined;
    sex?: 'male' | 'female' | 'other' | undefined;
    leanBodyMassKg?: number | undefined;
  }): BmrResult {
    // Check if Katch-McArdle is viable (requires lean mass)
    if (params.leanBodyMassKg !== undefined && params.leanBodyMassKg > 0) {
      // BMR = 370 + (21.6 * LBM in kg)
      const bmr = 370 + 21.6 * params.leanBodyMassKg;
      return {
        formulaId: 'bmr_katch_mcardle_v1',
        value: Math.round(bmr),
        sufficiency: 'complete',
        method: 'katch_mcardle'
      };
    }

    // Default: Mifflin-St Jeor equation
    const missing: string[] = [];
    if (params.weightKg === undefined || params.weightKg <= 0) missing.push('weight_kg');
    if (params.heightCm === undefined || params.heightCm <= 0) missing.push('height_cm');
    if (params.ageYears === undefined || params.ageYears <= 0) missing.push('age_years');
    if (!params.sex || (params.sex !== 'male' && params.sex !== 'female')) missing.push('sex_for_calculation');

    if (missing.length > 0 || !params.weightKg || !params.heightCm || !params.ageYears || !params.sex) {
      return {
        formulaId: 'bmr_mifflin_v1',
        value: 0,
        sufficiency: 'insufficient',
        missingInputs: missing,
        method: 'mifflin_st_jeor'
      };
    }

    // Mifflin-St Jeor:
    // Men: (10 * weight in kg) + (6.25 * height in cm) - (5 * age in years) + 5
    // Women: (10 * weight in kg) + (6.25 * height in cm) - (5 * age in years) - 161
    const base = 10 * params.weightKg + 6.25 * params.heightCm - 5 * params.ageYears;
    const bmr = params.sex === 'male' ? base + 5 : base - 161;

    return {
      formulaId: 'bmr_mifflin_v1',
      value: Math.round(bmr),
      sufficiency: 'complete',
      method: 'mifflin_st_jeor'
    };
  }

  /**
   * Calculate Total Daily Energy Expenditure (TDEE).
   * TDEE = BMR * Physical Activity Level (PAL) multiplier
   */
  public calculateTdee(bmr: number, activityLevel?: ActivityLevel): TdeeResult {
    const multipliers: Record<ActivityLevel, number> = {
      sedentary: 1.2,
      lightly_active: 1.375,
      moderately_active: 1.55,
      very_active: 1.725,
      extremely_active: 1.9
    };

    if (!activityLevel || !multipliers[activityLevel] || bmr <= 0) {
      return {
        formulaId: 'tdee_pal_v1',
        value: 0,
        bmr,
        activityLevel: activityLevel || 'sedentary',
        multiplier: 1.2,
        sufficiency: 'insufficient',
        missingInputs: ['activity_level', ...(bmr <= 0 ? ['valid_bmr'] : [])]
      };
    }

    const multiplier = multipliers[activityLevel];
    const tdee = Math.round(bmr * multiplier);

    return {
      formulaId: 'tdee_pal_v1',
      value: tdee,
      bmr,
      activityLevel,
      multiplier,
      sufficiency: 'complete'
    };
  }

  /**
   * Calculate Calorie Targets with Clinical Safety Guardrails.
   * Guardrails:
   * - Female calorie floor: 1200 kcal/day
   * - Male calorie floor: 1500 kcal/day
   * - Maximum deficit: min(1000 kcal, 25% of TDEE)
   * - Special populations (pregnancy, medical flags) -> refusal with referral
   */
  public calculateCalorieTargets(params: {
    tdee: number;
    sex?: 'male' | 'female' | 'other' | undefined;
    specialFlags?: { isPregnant?: boolean | undefined; hasMedicalCondition?: boolean | undefined } | undefined;
  }): CalorieTargetsResult {
    if (params.specialFlags?.isPregnant || params.specialFlags?.hasMedicalCondition) {
      return {
        formulaId: 'calorie_targets_v1',
        maintenance: params.tdee,
        targets: {
          moderateLoss: { targetCalories: 0, weeklyDeficitKcal: 0, expectedRateKgPerWeek: 0 },
          standardLoss: { targetCalories: 0, weeklyDeficitKcal: 0, expectedRateKgPerWeek: 0 },
          maintenance: { targetCalories: params.tdee, weeklyDeficitKcal: 0, expectedRateKgPerWeek: 0 },
          moderateGain: { targetCalories: 0, weeklySurplusKcal: 0, expectedRateKgPerWeek: 0 }
        },
        guardrailsTriggered: ['SPECIAL_POPULATION_REFUSAL'],
        isRefused: true,
        refusalReason: 'Calorie targets cannot be safely auto-generated for pregnancy or active medical conditions. Please consult a qualified healthcare provider.',
        sufficiency: 'complete'
      };
    }

    if (params.tdee <= 0) {
      return {
        formulaId: 'calorie_targets_v1',
        maintenance: 0,
        targets: {
          moderateLoss: { targetCalories: 0, weeklyDeficitKcal: 0, expectedRateKgPerWeek: 0 },
          standardLoss: { targetCalories: 0, weeklyDeficitKcal: 0, expectedRateKgPerWeek: 0 },
          maintenance: { targetCalories: 0, weeklyDeficitKcal: 0, expectedRateKgPerWeek: 0 },
          moderateGain: { targetCalories: 0, weeklySurplusKcal: 0, expectedRateKgPerWeek: 0 }
        },
        guardrailsTriggered: [],
        isRefused: false,
        sufficiency: 'insufficient',
        missingInputs: ['tdee']
      };
    }

    const calorieFloor = params.sex === 'female' ? 1200 : 1500;
    const maxDeficitAllowed = Math.min(1000, Math.round(params.tdee * 0.25));
    const guardrailsTriggered: string[] = [];

    // 1 kg fat ~= 7700 kcal. 0.5 kg loss/week ~= 550 kcal/day deficit. 0.25 kg loss/week ~= 275 kcal/day deficit.
    // Moderate loss: 300 kcal/day deficit (~0.27 kg/week)
    let modLossDeficit = 300;
    if (modLossDeficit > maxDeficitAllowed) {
      modLossDeficit = maxDeficitAllowed;
      guardrailsTriggered.push('MAX_DEFICIT_CAPPED');
    }
    let modLossCalories = params.tdee - modLossDeficit;
    if (modLossCalories < calorieFloor) {
      modLossCalories = calorieFloor;
      modLossDeficit = params.tdee - calorieFloor;
      guardrailsTriggered.push('CALORIE_FLOOR_ENFORCED');
    }

    // Standard loss: 500 kcal/day deficit (~0.45 kg/week)
    let stdLossDeficit = 500;
    if (stdLossDeficit > maxDeficitAllowed) {
      stdLossDeficit = maxDeficitAllowed;
      guardrailsTriggered.push('MAX_DEFICIT_CAPPED');
    }
    let stdLossCalories = params.tdee - stdLossDeficit;
    if (stdLossCalories < calorieFloor) {
      stdLossCalories = calorieFloor;
      stdLossDeficit = params.tdee - calorieFloor;
      guardrailsTriggered.push('CALORIE_FLOOR_ENFORCED');
    }

    // Moderate gain: 300 kcal surplus
    const modGainCalories = params.tdee + 300;

    return {
      formulaId: 'calorie_targets_v1',
      maintenance: params.tdee,
      targets: {
        moderateLoss: {
          targetCalories: modLossCalories,
          weeklyDeficitKcal: modLossDeficit * 7,
          expectedRateKgPerWeek: Math.round(((modLossDeficit * 7) / 7700) * 100) / 100
        },
        standardLoss: {
          targetCalories: stdLossCalories,
          weeklyDeficitKcal: stdLossDeficit * 7,
          expectedRateKgPerWeek: Math.round(((stdLossDeficit * 7) / 7700) * 100) / 100
        },
        maintenance: {
          targetCalories: params.tdee,
          weeklyDeficitKcal: 0,
          expectedRateKgPerWeek: 0
        },
        moderateGain: {
          targetCalories: modGainCalories,
          weeklySurplusKcal: 300 * 7,
          expectedRateKgPerWeek: Math.round(((300 * 7) / 7700) * 100) / 100
        }
      },
      guardrailsTriggered: Array.from(new Set(guardrailsTriggered)),
      isRefused: false,
      sufficiency: 'complete'
    };
  }

  /**
   * Calculate Macronutrient distribution based on target calories and weight.
   * Standard evidence-based distribution:
   * - Protein: 1.8g/kg body weight (4 kcal/g)
   * - Fat: 25% of total calories (9 kcal/g)
   * - Carbohydrates: Remaining calories (4 kcal/g)
   */
  public calculateMacroDistribution(targetCalories: number, weightKg: number): MacroTargetsResult {
    // Protein: 1.8g per kg body mass
    const proteinGrams = Math.round(weightKg * 1.8);
    const proteinKcal = proteinGrams * 4;

    // Fat: 25% of target calories
    const fatKcal = Math.round(targetCalories * 0.25);
    const fatGrams = Math.round(fatKcal / 9);

    // Carbs: Remaining calories
    const remainingKcal = Math.max(0, targetCalories - proteinKcal - fatKcal);
    const carbsGrams = Math.round(remainingKcal / 4);
    const carbsKcal = carbsGrams * 4;

    const totalCalculatedKcal = proteinKcal + fatKcal + carbsKcal;

    return {
      formulaId: 'macro_distribution_v1',
      targetCalories,
      proteinGrams,
      proteinKcal,
      proteinPct: Math.round((proteinKcal / totalCalculatedKcal) * 100),
      fatGrams,
      fatKcal,
      fatPct: Math.round((fatKcal / totalCalculatedKcal) * 100),
      carbsGrams,
      carbsKcal,
      carbsPct: Math.round((carbsKcal / totalCalculatedKcal) * 100),
      sufficiency: 'complete'
    };
  }

  /**
   * Project Goal Timeline with Rate-of-Change Guardrails.
   * Max safe loss rate: 1.0 kg/week or 1% body weight/week.
   */
  public projectWeightTimeline(params: {
    currentWeightKg?: number | undefined;
    targetWeightKg?: number | undefined;
    weeklyRateKg?: number | undefined;
    startDate?: Date | undefined;
  }): WeightTimelineProjection {
    const missing: string[] = [];
    if (params.currentWeightKg === undefined || params.currentWeightKg <= 0) missing.push('current_weight_kg');
    if (params.targetWeightKg === undefined || params.targetWeightKg <= 0) missing.push('target_weight_kg');
    if (params.weeklyRateKg === undefined || params.weeklyRateKg === 0) missing.push('weekly_rate_kg');

    if (missing.length > 0 || !params.currentWeightKg || !params.targetWeightKg || !params.weeklyRateKg) {
      return {
        formulaId: 'weight_timeline_v1',
        currentWeightKg: params.currentWeightKg || 0,
        targetWeightKg: params.targetWeightKg || 0,
        deltaKg: 0,
        weeklyRateKg: params.weeklyRateKg || 0,
        estimatedWeeks: 0,
        projectedTargetDate: '',
        isSafeRate: true,
        sufficiency: 'insufficient',
        missingInputs: missing
      };
    }

    const deltaKg = Math.round((params.targetWeightKg - params.currentWeightKg) * 100) / 100;
    const weeklyRate = Math.abs(params.weeklyRateKg);
    const estimatedWeeks = Math.ceil(Math.abs(deltaKg) / weeklyRate);

    // Max safe weekly rate check: 1.0 kg or 1% of body weight
    const maxSafeWeeklyLoss = Math.max(1.0, params.currentWeightKg * 0.01);
    const isSafeRate = weeklyRate <= maxSafeWeeklyLoss;
    let guardrailWarning: string | undefined;

    if (!isSafeRate) {
      guardrailWarning = `Weekly rate of ${weeklyRate} kg exceeds clinical safety guideline of max ${maxSafeWeeklyLoss.toFixed(1)} kg/week (1% body weight).`;
    }

    const start = params.startDate ? new Date(params.startDate) : new Date();
    const targetDate = new Date(start.getTime() + estimatedWeeks * 7 * 24 * 60 * 60 * 1000);

    return {
      formulaId: 'weight_timeline_v1',
      currentWeightKg: params.currentWeightKg,
      targetWeightKg: params.targetWeightKg,
      deltaKg,
      weeklyRateKg: params.weeklyRateKg,
      estimatedWeeks,
      projectedTargetDate: targetDate.toISOString().split('T')[0] ?? '',
      isSafeRate,
      guardrailWarning,
      sufficiency: 'complete'
    };
  }
}
