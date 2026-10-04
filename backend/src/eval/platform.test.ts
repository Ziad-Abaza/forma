import { describe, it, expect } from 'vitest';
import { AiGateway } from '../modules/ai-gateway/gateway.js';
import { ToolRegistry } from '../modules/assistant/tools.js';
import { AiContextEngine } from '../modules/assistant/context.js';
import { AiTraceService } from '../modules/ai-trace/service.js';
import { UserProfile } from '../modules/profile/model.js';

describe('Phase 3 AI Platform & Infrastructure (ADR-005, ADR-007, ADR-019, ADR-022)', () => {
  const masterKey = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  it('routes tasks deterministically according to ADR-023', () => {
    // Deterministic calculation requires no model
    const calcRoute = AiGateway.routeTask('deterministic_calculation');
    expect(calcRoute.requiresModel).toBe(false);

    // Intent classification routed to lightweight model
    const intentRoute = AiGateway.routeTask('intent_classification');
    expect(intentRoute.requiresModel).toBe(true);
    expect(intentRoute.modelId).toBe('gemini-1.5-flash');

    // Deep multi-step analysis routed to high reasoning model
    const deepRoute = AiGateway.routeTask('deep_multistep_analysis');
    expect(deepRoute.requiresModel).toBe(true);
    expect(deepRoute.provider).toBe('openai');
    expect(deepRoute.modelId).toBe('gpt-4o');
  });

  it('handles BYOK envelope encryption securely with write-only masking', () => {
    const rawApiKey = 'sk-proj-supersecretkey1234567890';
    const encrypted = AiGateway.encryptByokKey(rawApiKey, masterKey);

    expect(encrypted.maskedKey).toBe('sk-...7890');
    expect(encrypted.encryptedKey).not.toContain('supersecretkey');

    const decrypted = AiGateway.decryptByokKey(
      encrypted.encryptedKey,
      encrypted.iv,
      encrypted.authTag,
      masterKey
    );
    expect(decrypted).toBe(rawApiKey);
  });

  it('invokes schema-validated tools with server-injected context', async () => {
    const mockProfile: UserProfile = {
      userId: 'u_ai_1',
      heightCm: 175,
      sexForCalculation: 'female',
      dateOfBirth: '1998-04-12',
      activityLevel: 'moderately_active',
      preferredLanguage: 'en',
      preferredNumeralSystem: 'western',
      preferredUnits: { mass: 'kg', length: 'cm', energy: 'kcal' },
      attributes: {},
      calculationSnapshots: [],
      updatedAt: new Date().toISOString(),
    };

    const res = await ToolRegistry.invokeTool(
      'calculate_tdee_and_targets',
      { weightKg: 65, goalType: 'fat_loss', rateKgPerWeek: 0.5 },
      {
        userId: 'u_ai_1',
        profile: mockProfile,
        observations: [],
        goals: [],
      }
    );

    expect(res.bmr.bmrKcal).toBeGreaterThan(1200);
    expect(res.tdee.tdeeKcal).toBeGreaterThan(res.targetCalories.targetCalories);
    expect(res.macros.proteinGrams).toBeGreaterThan(100);
  });

  it('enforces AI Context Engine tier planning and emits context manifest', () => {
    const tier0 = AiContextEngine.planTier('Hello, what is visceral fat?');
    expect(tier0).toBe(0);

    const tier1 = AiContextEngine.planTier('How am I doing with my calorie target?');
    expect(tier1).toBe(1);

    const assembled = AiContextEngine.assembleContext(1, {
      identityLite: { age: 28 },
      bodyStatus: { weight: 70 },
      anomalies: [],
    });

    expect(assembled.manifest.tier).toBe(1);
    expect(assembled.manifest.includedSections).toContain('identityLite');
    expect(assembled.manifest.includedSections).toContain('bodyStatus');
    expect(assembled.manifest.watermark.startsWith('wm_')).toBe(true);
  });

  it('records content-free AI Trace Records without sensitive health data', () => {
    const trace = AiTraceService.recordTrace({
      userId: 'u_ai_1',
      operationType: 'assistant_turn',
      taskClass: 'structured_analysis',
      provider: 'openai',
      model: 'gpt-4o-mini',
      routingReason: 'Intent analysis',
      versions: {
        promptVersion: '1.0.0',
        policyVersion: '1.0.0',
        toolSchemaVersion: '1.0.0',
        formulaVersion: '1.0.0',
      },
      contextManifest: {
        tier: 1,
        includedSections: ['bodyStatus'],
        excludedSections: [],
        recordsCount: 1,
        budgetConsumedTokens: 350,
        watermark: 'wm_123',
      },
      toolsInvoked: [{ toolName: 'get_health_snapshot', durationMs: 12, success: true }],
      evidenceTypes: ['retrieved', 'calculated'],
      safetyCategory: 'wellness',
      guardrailsTriggered: [],
      budgetConsumed: {
        inputTokens: 420,
        outputTokens: 90,
        latencyMs: 310,
        costUsd: 0.0001,
      },
      outcome: 'success',
    });

    expect(trace.id.startsWith('trace_')).toBe(true);
    // Confirm no raw text or prompt content exists on the trace object
    expect((trace as any).prompt).toBeUndefined();
    expect((trace as any).response).toBeUndefined();
    expect((trace as any).healthValues).toBeUndefined();
  });
});
