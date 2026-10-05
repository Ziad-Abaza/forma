import { describe, it, expect, beforeAll } from 'vitest';
import { runMigrations } from '../core/database/migrate.js';
import { IdentityService } from '../modules/identity/service.js';
import { MeasurementsService } from '../modules/measurements/service.js';
import { SnapshotEngine } from '../modules/analytics/snapshot.js';
import { AIContextEngine } from '../modules/ai/context/engine.js';
import { ContextPlanner } from '../modules/ai/context/planner.js';
import { SafetyClassifier } from '../modules/ai/safety/classifier.js';
import { CalculationEngine } from '../modules/calculations/engine.js';
import { GOLDEN_EVALUATION_DATASET } from './golden/personas.js';

describe('Phase 6: AI Evaluation Matrix & Numeric Grounding Gate (Blueprint §31.1 Gate 3, §31.2)', () => {
  let userEnId: string;
  let userArId: string;
  let emptyUserId: string;
  let contextEngine: AIContextEngine;
  let calcEngine: CalculationEngine;

  beforeAll(async () => {
    await runMigrations();

    calcEngine = new CalculationEngine();
    const snapshotEngine = new SnapshotEngine();
    contextEngine = new AIContextEngine({
      snapshotService: snapshotEngine,
      measurementsService: MeasurementsService
    });

    // 1. Setup English user with recorded observations
    const userEn = await IdentityService.register(
      {
        email: `eval_matrix_en_${Date.now()}@example.com`,
        password: 'Password123!',
        dateOfBirth: '1992-04-10',
        heightCm: 182,
        sexForCalculation: 'male',
        locale: 'en',
        numeralSystem: 'western',
        consents: { termsOfService: true, healthDataProcessing: true, aiThirdPartyProcessing: true }
      },
      'corr-setup-eval-en'
    );
    userEnId = userEn.user.id;

    await MeasurementsService.recordObservation(
      userEnId,
      {
        typeCode: 'weight',
        value: 81.4,
        unit: 'kg',
        observedAt: new Date().toISOString(),
        originType: 'manual_entry',
        epistemicClass: 'measured',
        actor: 'user'
      },
      'corr-eval-weight-en'
    );

    // 2. Setup Arabic user with recorded observations
    const userAr = await IdentityService.register(
      {
        email: `eval_matrix_ar_${Date.now()}@example.com`,
        password: 'Password123!',
        dateOfBirth: '1994-07-22',
        heightCm: 170,
        sexForCalculation: 'female',
        locale: 'ar',
        numeralSystem: 'eastern_arabic',
        consents: { termsOfService: true, healthDataProcessing: true, aiThirdPartyProcessing: true }
      },
      'corr-setup-eval-ar'
    );
    userArId = userAr.user.id;

    await MeasurementsService.recordObservation(
      userArId,
      {
        typeCode: 'weight',
        value: 64.2,
        unit: 'kg',
        observedAt: new Date().toISOString(),
        originType: 'manual_entry',
        epistemicClass: 'measured',
        actor: 'user'
      },
      'corr-eval-weight-ar'
    );

    // 3. Setup Empty user with 0 measurements
    const emptyUser = await IdentityService.register(
      {
        email: `eval_matrix_empty_${Date.now()}@example.com`,
        password: 'Password123!',
        dateOfBirth: '1998-01-01',
        heightCm: 175,
        sexForCalculation: 'male',
        locale: 'en',
        numeralSystem: 'western',
        consents: { termsOfService: true, healthDataProcessing: true, aiThirdPartyProcessing: true }
      },
      'corr-setup-eval-empty'
    );
    emptyUserId = emptyUser.user.id;
  });

  describe('1. Golden Dataset Test Matrix (Blueprint §31.2)', () => {
    it('evaluates all golden test cases against intent, tier, and safety policies', () => {
      for (const tc of GOLDEN_EVALUATION_DATASET) {
        const plan = ContextPlanner.planIntentAndTier(tc.userPrompt);
        expect(plan.tier).toBe(tc.expectedTier);
        expect(plan.intent).toBe(tc.expectedIntent);

        const safety = SafetyClassifier.classify(tc.userPrompt);
        expect(safety.category).toBe(tc.expectedSafetyCategory);
      }
    });
  });

  describe('2. Numeric Grounding & Zero-Hallucination Abstention (Gate 3)', () => {
    it('grounds recorded weight in assembled context with exact numeric fidelity and measured epistemic class', async () => {
      const bundle = await contextEngine.assembleContext(userEnId, 'What is my current weight?');
      expect(bundle.isSufficient).toBe(true);
      expect(bundle.systemContextText).toContain('81.4');
      expect(bundle.systemContextText).toContain('[Measured]');
      expect(bundle.manifest.includedSections).toContain('bodyStatus');
    });

    it('abstains cleanly on empty user profile without fabricating measurements', async () => {
      const bundle = await contextEngine.assembleContext(emptyUserId, 'What is my current body fat percentage?');
      expect(bundle.isSufficient).toBe(false);
      expect(bundle.insufficiencyReason).toContain('Please log your first body measurement (e.g. weight)');
      expect(bundle.manifest.recordCount).toBe(0);
    });
  });

  describe('3. Calculation Engine Pure Arithmetic Verification (Gate 5, Invariant 4)', () => {
    it('calculates deterministic BMR and TDEE with exact formula versioning', () => {
      const bmr = calcEngine.calculateBmr({
        weightKg: 81.4,
        heightCm: 182,
        ageYears: 34,
        sex: 'male'
      });

      expect(bmr.formulaId).toBe('bmr_mifflin_v1');
      expect(bmr.value).toBe(1787);
      expect(bmr.sufficiency).toBe('complete');

      const tdee = calcEngine.calculateTdee(bmr.value, 'sedentary');
      expect(tdee.formulaId).toBe('tdee_pal_v1');
      expect(tdee.value).toBe(2144);
      expect(tdee.sufficiency).toBe('complete');
    });

    it('enforces biological calorie floors across sexes', () => {
      const maleTargets = calcEngine.calculateCalorieTargets({
        tdee: 1600,
        sex: 'male'
      });
      // Male floor is 1500 kcal
      expect(maleTargets.targets.standardLoss.targetCalories).toBe(1500);

      const femaleTargets = calcEngine.calculateCalorieTargets({
        tdee: 1300,
        sex: 'female'
      });
      // Female floor is 1200 kcal
      expect(femaleTargets.targets.standardLoss.targetCalories).toBe(1200);
    });
  });

  describe('4. Bilingual Arabic / English Parity & Intent Mapping (Gate 9)', () => {
    it('classifies Arabic prompts with exact intent and tier parity', () => {
      const planAr = ContextPlanner.planIntentAndTier('ما هو وزني الحالي؟');
      expect(planAr.tier).toBe(1);
      expect(planAr.intent).toBe('data_lookup');

      const calcPlanAr = ContextPlanner.planIntentAndTier('احسب معدل الأيض الأساسي والسعرات');
      expect(calcPlanAr.tier).toBe(2);
      expect(calcPlanAr.intent).toBe('calculation');
    });

    it('assembles grounded context for Arabic user with correct metrics', async () => {
      const bundle = await contextEngine.assembleContext(userArId, 'ما هو وزني الحالي؟');
      expect(bundle.isSufficient).toBe(true);
      expect(bundle.systemContextText).toContain('64.2');
      expect(bundle.systemContextText).toContain('[Measured]');
    });
  });
});
