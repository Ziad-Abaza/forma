import { describe, it, expect } from 'vitest';
import { CalculationEngine } from './engine.js';

describe('Deterministic Calculation Engine (Reference Values, Property-Based & Safety Guardrails)', () => {
  const engine = new CalculationEngine();

  describe('BMI Calculations (WHO Criteria)', () => {
    it('accurately calculates BMI for known reference values', () => {
      // 70 kg, 175 cm -> 70 / (1.75^2) = 22.857... -> 22.9 (Normal)
      const res1 = engine.calculateBmi(70, 175);
      expect(res1.sufficiency).toBe('complete');
      expect(res1.value).toBe(22.9);
      expect(res1.category).toBe('normal');

      // 50 kg, 175 cm -> 50 / (1.75^2) = 16.326... -> 16.3 (Underweight)
      const res2 = engine.calculateBmi(50, 175);
      expect(res2.value).toBe(16.3);
      expect(res2.category).toBe('underweight');

      // 85 kg, 175 cm -> 85 / (1.75^2) = 27.755... -> 27.8 (Overweight)
      const res3 = engine.calculateBmi(85, 175);
      expect(res3.value).toBe(27.8);
      expect(res3.category).toBe('overweight');

      // 100 kg, 175 cm -> 100 / (1.75^2) = 32.653... -> 32.7 (Obese Class 1)
      const res4 = engine.calculateBmi(100, 175);
      expect(res4.value).toBe(32.7);
      expect(res4.category).toBe('obese_class_1');
    });

    it('handles missing or non-positive inputs with sufficiency: insufficient', () => {
      const res = engine.calculateBmi(undefined, 175);
      expect(res.sufficiency).toBe('insufficient');
      expect(res.missingInputs).toContain('weight_kg');

      const resZero = engine.calculateBmi(70, 0);
      expect(resZero.sufficiency).toBe('insufficient');
      expect(resZero.missingInputs).toContain('height_cm');
    });

    it('satisfies monotonicity property: increasing weight strictly increases BMI', () => {
      const height = 180;
      let prevBmi = 0;
      for (let weight = 50; weight <= 120; weight += 5) {
        const res = engine.calculateBmi(weight, height);
        expect(res.value).toBeGreaterThan(prevBmi);
        prevBmi = res.value;
      }
    });
  });

  describe('BMR Calculations (Mifflin-St Jeor & Katch-McArdle)', () => {
    it('calculates Mifflin-St Jeor for known reference male and female profiles', () => {
      // Male: 80 kg, 180 cm, 30 years
      // Base = 10*80 + 6.25*180 - 5*30 = 800 + 1125 - 150 = 1775
      // Male = 1775 + 5 = 1780 kcal
      const maleRes = engine.calculateBmr({
        weightKg: 80,
        heightCm: 180,
        ageYears: 30,
        sex: 'male'
      });
      expect(maleRes.sufficiency).toBe('complete');
      expect(maleRes.value).toBe(1780);
      expect(maleRes.method).toBe('mifflin_st_jeor');

      // Female: 65 kg, 165 cm, 28 years
      // Base = 10*65 + 6.25*165 - 5*28 = 650 + 1031.25 - 140 = 1541.25
      // Female = 1541.25 - 161 = 1380.25 -> 1380 kcal
      const femaleRes = engine.calculateBmr({
        weightKg: 65,
        heightCm: 165,
        ageYears: 28,
        sex: 'female'
      });
      expect(femaleRes.sufficiency).toBe('complete');
      expect(femaleRes.value).toBe(1380);
      expect(femaleRes.method).toBe('mifflin_st_jeor');
    });

    it('prefers Katch-McArdle when lean body mass is known', () => {
      // LBM = 60 kg -> BMR = 370 + (21.6 * 60) = 370 + 1296 = 1666 kcal
      const katchRes = engine.calculateBmr({
        weightKg: 75,
        heightCm: 178,
        ageYears: 25,
        sex: 'male',
        leanBodyMassKg: 60
      });
      expect(katchRes.sufficiency).toBe('complete');
      expect(katchRes.value).toBe(1666);
      expect(katchRes.method).toBe('katch_mcardle');
    });

    it('reports missing inputs when data is incomplete', () => {
      const res = engine.calculateBmr({ weightKg: 80, heightCm: 180 });
      expect(res.sufficiency).toBe('insufficient');
      expect(res.missingInputs).toContain('age_years');
      expect(res.missingInputs).toContain('sex_for_calculation');
    });
  });

  describe('TDEE & Activity Multipliers', () => {
    it('applies exact Physical Activity Level (PAL) multipliers', () => {
      const bmr = 1500;
      expect(engine.calculateTdee(bmr, 'sedentary').value).toBe(Math.round(1500 * 1.2)); // 1800
      expect(engine.calculateTdee(bmr, 'lightly_active').value).toBe(Math.round(1500 * 1.375)); // 2063
      expect(engine.calculateTdee(bmr, 'moderately_active').value).toBe(Math.round(1500 * 1.55)); // 2325
      expect(engine.calculateTdee(bmr, 'very_active').value).toBe(Math.round(1500 * 1.725)); // 2588
      expect(engine.calculateTdee(bmr, 'extremely_active').value).toBe(Math.round(1500 * 1.9)); // 2850
    });
  });

  describe('Calorie Targets & Clinical Safety Guardrails', () => {
    it('enforces female floor of 1200 kcal/day and male floor of 1500 kcal/day', () => {
      // Female with low TDEE: 1350 kcal
      const femaleLow = engine.calculateCalorieTargets({ tdee: 1350, sex: 'female' });
      expect(femaleLow.targets.standardLoss.targetCalories).toBe(1200); // 1350 - 500 = 850, clamped to 1200
      expect(femaleLow.guardrailsTriggered).toContain('CALORIE_FLOOR_ENFORCED');

      // Male with low TDEE: 1700 kcal
      const maleLow = engine.calculateCalorieTargets({ tdee: 1700, sex: 'male' });
      expect(maleLow.targets.standardLoss.targetCalories).toBe(1500); // 1700 - 500 = 1200, clamped to 1500
      expect(maleLow.guardrailsTriggered).toContain('CALORIE_FLOOR_ENFORCED');
    });

    it('caps maximum deficit to 25% of TDEE', () => {
      // TDEE = 1900 kcal, sex = 'female' (floor 1200). 25% max deficit = 475 kcal.
      // Standard deficit of 500 kcal is capped to 475 kcal.
      const res = engine.calculateCalorieTargets({ tdee: 1900, sex: 'female' });
      expect(res.guardrailsTriggered).toContain('MAX_DEFICIT_CAPPED');
      expect(res.targets.standardLoss.targetCalories).toBe(1900 - 475); // 1425 kcal
    });

    it('refuses calorie targets and recommends healthcare provider for special populations (pregnancy / medical flags)', () => {
      const pregnantRes = engine.calculateCalorieTargets({
        tdee: 2200,
        sex: 'female',
        specialFlags: { isPregnant: true }
      });
      expect(pregnantRes.isRefused).toBe(true);
      expect(pregnantRes.guardrailsTriggered).toContain('SPECIAL_POPULATION_REFUSAL');
      expect(pregnantRes.refusalReason).toBeDefined();

      const medicalRes = engine.calculateCalorieTargets({
        tdee: 2400,
        sex: 'male',
        specialFlags: { hasMedicalCondition: true }
      });
      expect(medicalRes.isRefused).toBe(true);
    });
  });

  describe('Macronutrient Distribution', () => {
    it('calculates balanced macronutrients adhering to energy math', () => {
      const targetCalories = 2000;
      const weightKg = 70;
      const macros = engine.calculateMacroDistribution(targetCalories, weightKg);

      // Protein: 70 * 1.8 = 126g -> 504 kcal
      expect(macros.proteinGrams).toBe(126);
      expect(macros.proteinKcal).toBe(504);

      // Fat: 25% of 2000 = 500 kcal -> 500 / 9 = 56g
      expect(macros.fatKcal).toBe(500);
      expect(macros.fatGrams).toBe(56);

      // Carbs: 2000 - 504 - 500 = 996 kcal -> 996 / 4 = 249g
      expect(macros.carbsGrams).toBe(249);
      expect(macros.carbsKcal).toBe(996);

      // Sum of percentages should be ~100%
      expect(macros.proteinPct + macros.fatPct + macros.carbsPct).toBeGreaterThanOrEqual(99);
      expect(macros.proteinPct + macros.fatPct + macros.carbsPct).toBeLessThanOrEqual(101);
    });
  });

  describe('Goal Timeline & Weekly Rate Guardrails', () => {
    it('projects realistic timeline for safe weight loss rate', () => {
      const proj = engine.projectWeightTimeline({
        currentWeightKg: 85,
        targetWeightKg: 80, // delta: -5 kg
        weeklyRateKg: 0.5,
        startDate: new Date('2026-10-01')
      });
      expect(proj.sufficiency).toBe('complete');
      expect(proj.estimatedWeeks).toBe(10); // 5 / 0.5 = 10 weeks
      expect(proj.isSafeRate).toBe(true);
      expect(proj.guardrailWarning).toBeUndefined();
    });

    it('triggers warning when weekly loss rate exceeds clinical safety limit (1.0 kg/week or 1% body weight)', () => {
      const proj = engine.projectWeightTimeline({
        currentWeightKg: 80,
        targetWeightKg: 70,
        weeklyRateKg: 1.5, // 1.5 kg/week exceeds 1.0 kg/week and 0.8 kg/week (1%)
        startDate: new Date('2026-10-01')
      });
      expect(proj.isSafeRate).toBe(false);
      expect(proj.guardrailWarning).toContain('exceeds clinical safety guideline');
    });
  });
});
