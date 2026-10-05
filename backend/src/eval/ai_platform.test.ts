import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { runMigrations } from '../core/database/migrate.js';
import { getPool, closePool } from '../core/database/index.js';
import { AIGateway } from '../modules/ai/gateway/gateway.js';
import { BYOKService } from '../modules/ai/gateway/byok.js';
import { ToolRegistry, ToolExecutor } from '../modules/ai/tools/executor.js';
import { ContextPlanner } from '../modules/ai/context/planner.js';
import { AIContextEngine } from '../modules/ai/context/engine.js';
import { AIBudgetEnforcer, BUDGET_PROFILES } from '../modules/ai/budget/index.js';
import { AITraceService } from '../modules/ai/traces/service.js';
import { SafetyClassifier } from '../modules/ai/safety/classifier.js';
import { GOLDEN_EVALUATION_DATASET } from './golden/personas.js';
import { IdentityService } from '../modules/identity/service.js';
import { MeasurementsService } from '../modules/measurements/service.js';
import { SnapshotEngine } from '../modules/analytics/snapshot.js';
import { AnalyticsService } from '../modules/analytics/service.js';
import { GoalsService } from '../modules/goals/service.js';
import { PrivacyOrchestrator } from '../modules/privacy/index.js';

describe('Phase 3: AI Context & Provider Infrastructure Integration Tests', () => {
  let byokService: BYOKService;
  let snapshotEngine: SnapshotEngine;
  let analyticsService: AnalyticsService;
  let goalsService: GoalsService;
  let traceService: AITraceService;
  let testUserId: string;

  beforeAll(async () => {
    process.env['NODE_ENV'] = 'test';
    await runMigrations();

    const pool = getPool();
    byokService = new BYOKService(pool);
    snapshotEngine = new SnapshotEngine();
    analyticsService = new AnalyticsService();
    goalsService = new GoalsService();
    traceService = new AITraceService(pool);

    const email = `ai_eval_${Date.now()}@example.com`;
    const reg = await IdentityService.register(
      {
        email,
        password: 'SecurePassword123!',
        dateOfBirth: '1995-05-15',
        heightCm: 180,
        sexForCalculation: 'male',
        locale: 'en',
        numeralSystem: 'western',
        consents: { termsOfService: true, healthDataProcessing: true, aiThirdPartyProcessing: true },
      },
      'corr-ai-setup'
    );
    testUserId = reg.user.id;
  });

  afterAll(async () => {
    if (testUserId) {
      await PrivacyOrchestrator.purgeUserAccount(testUserId, 'corr-test-cleanup');
    }
    await closePool();
  });

  // 1. AI Gateway Multi-Provider & Routing Tests
  describe('AI Gateway & Provider Abstraction', () => {
    it('initializes with multiple provider adapters and routes requests', async () => {
      const gateway = new AIGateway(byokService);
      expect(gateway.getAdapter('google')).toBeDefined();
      expect(gateway.getAdapter('secondary')).toBeDefined();

      const secRes = await gateway.execute('conversational', {
        prompt: 'Hello from test',
      });

      expect(secRes.result).toBeDefined();
      expect(secRes.routing.selectedModel).toBeDefined();
      expect(secRes.routing.latencyMs).toBeGreaterThanOrEqual(0);
    });

    it('Invariant: blocks LLM execution on deterministic calculation tasks', async () => {
      const gateway = new AIGateway();
      await expect(
        gateway.execute('calculation', { prompt: 'calculate calories' })
      ).rejects.toThrow(/deterministic and must not be routed to an LLM/);
    });

    it('falls back gracefully to secondary provider when primary encounters error', async () => {
      const gateway = new AIGateway();
      // Replace google adapter with one that throws
      gateway.registerAdapter({
        providerName: 'google',
        isAvailable: async () => true,
        generateText: async () => {
          throw new Error('Primary provider simulated outage');
        },
      });

      const res = await gateway.execute('general_qa', {
        prompt: 'What is protein synthesis?',
      });

      expect(res.routing.fallbackUsed).toBe(true);
      expect(res.routing.selectedProvider).toBe('secondary');
      expect(res.result.text).toContain('[Secondary AI Response');
    });
  });

  // 2. BYOK Readiness & Encrypted Key Custody
  describe('BYOK Readiness & Encrypted Key Custody', () => {
    it('encrypts and decrypts API keys with AES-256-GCM and generates fingerprint', () => {
      const plainKey = 'AIzaSyFakeKeyForTesting12345678';
      const { encrypted, fingerprint } = byokService.encryptKey(plainKey);

      expect(fingerprint).toBe('...5678');
      expect(encrypted).not.toContain(plainKey);

      const decrypted = byokService.decryptKey(encrypted);
      expect(decrypted).toBe(plainKey);
    });

    it('stores user BYOK credential in DB and resolves per request', async () => {
      const key = 'sk-user-test-key-99998888';
      const cred = await byokService.storeUserKey(testUserId, 'google', key);

      expect(cred.provider).toBe('google');
      expect(cred.keyFingerprint).toBe('...8888');

      const resolved = await byokService.resolveUserKey(testUserId, 'google');
      expect(resolved).toBe(key);
    });

    it('blocks storing keys for unallowlisted providers', async () => {
      await expect(
        byokService.storeUserKey(testUserId, 'unauthorized_provider', 'some-key-12345')
      ).rejects.toThrow(/not in the allowlist/);
    });
  });

  // 3. Tool Registry & Server-Mediated Execution
  describe('Tool Registry & Secure Execution Engine', () => {
    const registry = new ToolRegistry();
    const executor = new ToolExecutor(registry);

    it('injects identity server-side and removes any user-supplied userId from arguments', async () => {
      const ctx = {
        userId: testUserId,
        correlationId: 'test_corr_1',
        services: {
          snapshotService: snapshotEngine,
          measurementsService: MeasurementsService,
          goalsService,
          analyticsService,
        },
      };

      const maliciousArgs = {
        userId: '00000000-0000-0000-0000-000000000000',
        user_id: 'fake_injected_id',
        section: 'all',
      };

      const receipt = await executor.executeToolCall(
        'call_1',
        'get_health_snapshot',
        maliciousArgs,
        ctx
      );

      expect(receipt.success).toBe(true);
      expect(maliciousArgs).not.toHaveProperty('userId');
      expect(maliciousArgs).not.toHaveProperty('user_id');
    });

    it('enforces permission classes and rejects tools outside allowed permissions', async () => {
      const ctx = {
        userId: testUserId,
        correlationId: 'test_corr_2',
        services: {},
      };

      const receipt = await executor.executeToolCall(
        'call_2',
        'get_health_snapshot',
        {},
        ctx,
        ['sensitive-write'] // only sensitive-write allowed, tool is read-only
      );

      expect(receipt.success).toBe(false);
      expect(receipt.error).toContain('is not permitted for this turn');
    });

    it('executes get_calculated_metrics with exact deterministic WHO/Mifflin values', async () => {
      const ctx = {
        userId: testUserId,
        correlationId: 'test_corr_3',
        services: {},
      };

      // BMI test
      const bmiReceipt = await executor.executeToolCall(
        'call_bmi',
        'get_calculated_metrics',
        {
          formula: 'bmi',
          weightKg: 80,
          heightCm: 180,
        },
        ctx
      );

      expect(bmiReceipt.success).toBe(true);
      expect(bmiReceipt.result.bmi).toBe(24.7);
      expect(bmiReceipt.result.classification).toBe('normal');

      // TDEE test
      const tdeeReceipt = await executor.executeToolCall(
        'call_tdee',
        'get_calculated_metrics',
        {
          formula: 'tdee',
          weightKg: 80,
          heightCm: 180,
          ageYears: 30,
          sex: 'male',
          activityLevel: 'moderate',
          goalType: 'weight_loss',
        },
        ctx
      );

      expect(tdeeReceipt.success).toBe(true);
      expect(tdeeReceipt.result.tdeeKcal).toBeGreaterThan(2000);
      expect(tdeeReceipt.result.targetCaloriesKcal).toBeGreaterThanOrEqual(1500); // Male clinical floor
    });
  });

  // 4. AI Context Engine & Tiered Planning
  describe('AI Context Engine & Tiered Planning', () => {
    it('plans Tier 0 for general knowledge questions without user health data', async () => {
      const engine = new AIContextEngine({ snapshotService: snapshotEngine });
      const bundle = await engine.assembleContext(
        testUserId,
        'What is visceral fat and how does it differ from subcutaneous fat?'
      );

      expect(bundle.tier).toBe(0);
      expect(bundle.intentClass).toBe('general');
      expect(bundle.manifest.includedSections).toHaveLength(0);
      expect(bundle.manifest.recordCount).toBe(0);
      expect(bundle.systemContextText).not.toContain(testUserId);
      expect(bundle.isSufficient).toBe(true);
    });

    it('handles empty user gracefully: gates sufficiency and refuses hallucinated metrics', async () => {
      const freshEmail = `empty_${Date.now()}@example.com`;
      const freshUser = await IdentityService.register(
        {
          email: freshEmail,
          password: 'Password123!',
          dateOfBirth: '1990-01-01',
          heightCm: 165,
          sexForCalculation: 'female',
          locale: 'en',
          numeralSystem: 'western',
          consents: { termsOfService: true, healthDataProcessing: true, aiThirdPartyProcessing: true },
        },
        'corr-ai-empty'
      );

      const engine = new AIContextEngine({ snapshotService: snapshotEngine });
      const bundle = await engine.assembleContext(freshUser.user.id, 'What is my current weight and goal progress?');

      expect(bundle.tier).toBe(1);
      expect(bundle.isSufficient).toBe(false);
      expect(bundle.insufficiencyReason).toContain('Please log your first body measurement');
      expect(bundle.manifest.recordCount).toBe(0);

      await PrivacyOrchestrator.purgeUserAccount(freshUser.user.id, 'corr-empty-cleanup');
    });

    it('assembles Tier 1 snapshot context with lineage watermark when data exists', async () => {
      // Add observation
      await MeasurementsService.recordObservation(
        testUserId,
        {
          typeCode: 'weight',
          value: 85.0,
          unit: 'kg',
          observedAt: new Date().toISOString(),
          timeZone: 'UTC',
          originType: 'manual_entry',
          epistemicClass: 'measured',
          actor: 'user',
        },
        'corr-ai-obs'
      );

      const engine = new AIContextEngine({ snapshotService: snapshotEngine });
      const bundle = await engine.assembleContext(testUserId, 'How is my current weight?');

      expect(bundle.tier).toBe(1);
      expect(bundle.isSufficient).toBe(true);
      expect(bundle.manifest.includedSections).toContain('bodyStatus');
      expect(bundle.manifest.sourceWatermark).toBeDefined();
      expect(bundle.systemContextText).toContain('Latest Weight [Measured]: 85 kg');
    });
  });

  // 5. AI Data Budget Enforcement
  describe('AI Data Budget Enforcer', () => {
    it('halts and throws when tool calls exceed budget limit', () => {
      const enforcer = new AIBudgetEnforcer(BUDGET_PROFILES.minimal);
      enforcer.recordToolCall();
      enforcer.recordToolCall();

      expect(() => enforcer.recordToolCall()).toThrow(/tool calls \(3\) exceeded limit \(2\)/);
    });

    it('halts and throws when sequential rounds exceed limit', () => {
      const enforcer = new AIBudgetEnforcer(BUDGET_PROFILES.minimal);
      enforcer.recordRound();

      expect(() => enforcer.recordRound()).toThrow(/sequential rounds \(2\) exceeded limit \(1\)/);
    });

    it('tracks token consumption and reports consumption telemetry', () => {
      const enforcer = new AIBudgetEnforcer(BUDGET_PROFILES.standard);
      enforcer.recordToolCall();
      enforcer.recordTokens(350);

      const consumption = enforcer.getConsumption();
      expect(consumption.toolCalls).toBe(1);
      expect(consumption.tokensConsumed).toBe(350);
      expect(consumption.isExhausted).toBe(false);
    });
  });

  // 6. AI Traceability & Content-Free Ledger
  describe('AI Traceability & Content-Free Ledger', () => {
    it('emits content-free trace record with manifest and metadata', async () => {
      const trace = await traceService.emitTrace({
        userId: testUserId,
        correlationId: 'trace_test_corr',
        provider: 'google',
        modelId: 'gemini-3.8-flash',
        taskClass: 'conversational',
        intentClass: 'data_lookup',
        contextTier: 1,
        contextManifest: {
          tier: 1,
          intentClass: 'data_lookup',
          includedSections: ['overview', 'body_status'],
          excludedReasons: {},
          recordCount: 2,
          dataFreshness: 'fresh',
        },
        toolsInvoked: [{ tool: 'get_health_snapshot', success: true, latencyMs: 25 }],
        evidenceTypes: ['retrieved', 'calculated'],
        safetyCategory: 'A',
        budgetConsumed: {
          toolCalls: 1,
          sequentialRounds: 1,
          tokensConsumed: 120,
          elapsedMs: 250,
          isExhausted: false,
        },
        outcome: 'success',
      });

      expect(trace.id).toBeDefined();
      expect(trace.userId).toBe(testUserId);
      expect(trace.safetyCategory).toBe('A');

      // Verify traces retrieved from DB
      const userTraces = await traceService.getUserTraces(testUserId);
      expect(userTraces.length).toBeGreaterThan(0);
      expect(userTraces[0]!.contextManifest.includedSections).toContain('body_status');
    });

    it('includes AI traces in privacy export and erases them on purge', async () => {
      const exportData = await traceService.exportUserData(testUserId);
      expect(exportData.aiTracesCount).toBeGreaterThan(0);

      await traceService.purgeUserData(testUserId);
      const afterPurge = await traceService.getUserTraces(testUserId);
      expect(afterPurge).toHaveLength(0);
    });
  });

  // 7. Safety Classification & Golden Persona Evaluation
  describe('Safety Classification & Golden Evaluation Personas', () => {
    it('classifies Category D acute emergency symptoms and returns redirect guidance', () => {
      const res = SafetyClassifier.classify('I have severe chest pain and dizziness during my workout');
      expect(res.category).toBe('D');
      expect(res.mode).toBe('redirect');
      expect(res.guardrailsTriggered).toContain('acute_symptom_chest_pain');
      expect(res.redirectMessage).toContain('licensed healthcare professional or emergency');
    });

    it('classifies Category D disordered eating and extreme restriction', () => {
      const res = SafetyClassifier.classify('I plan to starve myself and fast for 3 weeks');
      expect(res.category).toBe('D');
      expect(res.mode).toBe('redirect');
      expect(res.guardrailsTriggered).toContain('disordered_eating_starve_myself');
    });

    it('evaluates all golden test cases against safety, tiers, and grounding expectations', async () => {
      for (const tc of GOLDEN_EVALUATION_DATASET) {
        const safety = SafetyClassifier.classify(tc.userPrompt);
        const plan = ContextPlanner.planIntentAndTier(tc.userPrompt);

        // Verify tier and safety category assertions
        if (tc.expectedSafetyCategory === 'D') {
          expect(safety.category).toBe('D');
          expect(safety.mode).toBe('redirect');
        } else {
          expect(plan.tier).toBe(tc.expectedTier);
          expect(plan.intent).toBe(tc.expectedIntent);
        }
      }
    });
  });
});
