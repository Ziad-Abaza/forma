import { describe, it, expect } from 'vitest';
import { CalculationEngine, SAFETY_GUARDRAILS, FORMULA_VERSIONS } from './engine.js';

describe('Deterministic Calculation Engine (ADR-010, §15)', () => {
  describe('BMI calculation', () => {
    it('calculates BMI with reproducible precision', () => {
      // 80 kg, 180 cm -> 80 / (1.8^2) = 24.691 -> 24.7
      const res = CalculationEngine.calculateBmi({ weightKg: 80, heightCm: 180 });
      expect(res.formulaId).toBe('BMI');
      expect(res.formulaVersion).toBe(FORMULA_VERSIONS.BMI);
      expect(res.dataSufficiency).toBe('complete');
      expect(res.value.bmi).toBe(24.7);
      expect(res.value.classification).toBe('normal_weight');
      expect(res.safetyFlags).toHaveLength(0);
    });

    it('identifies underweight caution', () => {
      // 45 kg, 170 cm -> 15.6 BMI
      const res = CalculationEngine.calculateBmi({ weightKg: 45, heightCm: 170 });
      expect(res.value.bmi).toBe(15.6);
      expect(res.value.classification).toBe('underweight');
      expect(res.safetyFlags).toContain('bmi_underweight_caution');
    });

    it('gracefully reports insufficient data when inputs are missing', () => {
      const res = CalculationEngine.calculateBmi({ weightKg: 80 });
      expect(res.dataSufficiency).toBe('insufficient');
      expect(res.missingInputs).toContain('heightCm');
    });
  });

  describe('BMR & TDEE calculation', () => {
    it('calculates Mifflin-St Jeor BMR for male and female', () => {
      // Male: 80 kg, 180 cm, 30 years -> (800) + (1125) - (150) + 5 = 1780
      const maleRes = CalculationEngine.calculateBmr({
        weightKg: 80,
        heightCm: 180,
        ageYears: 30,
        sex: 'male',
      });
      expect(maleRes.value.bmrKcal).toBe(1780);

      // Female: 65 kg, 165 cm, 30 years -> (650) + (1031.25) - (150) - 161 = 1370
      const femaleRes = CalculationEngine.calculateBmr({
        weightKg: 65,
        heightCm: 165,
        ageYears: 30,
        sex: 'female',
      });
      expect(femaleRes.value.bmrKcal).toBe(1370);
    });

    it('prefers Katch-McArdle formula when lean mass is provided', () => {
      // Lean mass 65 kg -> 370 + (21.6 * 65) = 1774
      const res = CalculationEngine.calculateBmr({
        weightKg: 85,
        leanMassKg: 65,
      });
      expect(res.formulaId).toBe('BMR_KATCH_MCARDLE');
      expect(res.value.bmrKcal).toBe(1774);
    });

    it('calculates TDEE using validated activity multipliers', () => {
      const res = CalculationEngine.calculateTdee({
        bmrKcal: 1780,
        activityLevel: 'moderately_active', // 1.55
      });
      expect(res.value.tdeeKcal).toBe(2759); // 1780 * 1.55 = 2759
    });
  });

  describe('Safety Guardrails (ADR-010, §15.5)', () => {
    it('enforces minimum calorie floor when deficit is too extreme', () => {
      // Female with low TDEE: 1400 kcal trying to lose 1 kg/week (-1100 kcal) -> would be 300 kcal!
      const res = CalculationEngine.calculateCalorieTarget({
        tdeeKcal: 1400,
        goalType: 'fat_loss',
        rateKgPerWeek: 1.0,
        sex: 'female',
      });

      // Must be clamped to female calorie floor (1200 kcal)
      expect(res.value.targetCalories).toBe(SAFETY_GUARDRAILS.MIN_CALORIE_FLOOR_FEMALE);
      expect(res.value.guardrailClamped).toBe(true);
      expect(res.safetyFlags.some((f) => f.includes('calorie_floor_enforced'))).toBe(true);
    });

    it('clamps unsafe user requested loss rates exceeding 1.0 kg/week', () => {
      const res = CalculationEngine.calculateCalorieTarget({
        tdeeKcal: 2800,
        goalType: 'fat_loss',
        rateKgPerWeek: 2.5, // Unsafe!
        sex: 'male',
      });

      expect(res.value.safeRateKgPerWeek).toBe(SAFETY_GUARDRAILS.MAX_SAFE_WEIGHT_LOSS_KG_PER_WEEK);
      expect(res.safetyFlags).toContain('excessive_loss_rate_clamped');
      expect(res.value.guardrailClamped).toBe(true);
    });
  });

  describe('Macronutrient distribution', () => {
    it('distributes protein, fats, and carbs properly based on goals', () => {
      const macros = CalculationEngine.calculateMacros({
        targetCalories: 2200,
        weightKg: 80,
        goalType: 'fat_loss',
      });

      // 80kg * 2.2g = 176g protein (704 kcal)
      expect(macros.value.proteinGrams).toBe(176);
      expect(macros.value.proteinCalories).toBe(704);

      // Fat 25% of 2200 = 550 kcal / 9 = 61g fat (549 kcal)
      expect(macros.value.fatGrams).toBe(61);

      // Carbs: remaining 2200 - (704 + 549) = 947 kcal / 4 = 237g
      expect(macros.value.carbGrams).toBe(237);
      expect(macros.dataSufficiency).toBe('complete');
    });
  });
});
