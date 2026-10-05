import { describe, it, expect, beforeAll, afterAll, vi } from 'vitest';
import { buildApp } from '../app.js';
import { closePool, withUserContext } from '../core/database/index.js';
import * as dbModule from '../core/database/index.js';
import { IdentityService } from '../modules/identity/service.js';
import { AssistantOrchestrator } from '../modules/assistant/orchestrator.js';
import { AIContextEngine } from '../modules/ai/context/engine.js';
import { AnalyticsService } from '../modules/analytics/service.js';
import { MeasurementsService } from '../modules/measurements/service.js';
import { GoalsService } from '../modules/goals/service.js';
import { PrivacyOrchestrator } from '../modules/privacy/index.js';
import type { FastifyInstance } from 'fastify';

describe('Gate 11: Resilience, Fault Tolerance & Provider Degradation Drills', () => {
  let app: FastifyInstance;
  let testUserId: string;

  beforeAll(async () => {
    app = buildApp();
    await app.ready();

    // Register valid test user with profile
    const registered = await IdentityService.register(
      {
        email: `resilience_${Date.now()}@example.com`,
        password: 'SecurePassword123!',
        dateOfBirth: '1992-05-15',
        heightCm: 180,
        sexForCalculation: 'male',
        locale: 'en',
        numeralSystem: 'western',
        consents: { termsOfService: true, healthDataProcessing: true, aiThirdPartyProcessing: true }
      },
      'corr-resilience-setup'
    );
    testUserId = registered.user.id;
  });

  afterAll(async () => {
    if (testUserId) {
      await PrivacyOrchestrator.purgeUserAccount(testUserId, 'corr-resilience-cleanup');
    }
    await app.close();
    await closePool();
  });

  it('Provider Outage Drill: Assistant gracefully degrades when AI provider returns 503 or times out', async () => {
    const orchestrator = new AssistantOrchestrator();

    // Mock the gateway's execute method to simulate total provider outage
    const gatewaySpy = vi.spyOn((orchestrator as any).gateway, 'execute').mockRejectedValueOnce(
      new Error('AI Gateway Error: 503 Service Unavailable (Google AI temporary overload)')
    );

    const result = await orchestrator.chat(
      testUserId,
      { message: 'What is my current body weight and recommendations?' },
      'corr-outage-drill-1'
    );

    // Verify system did not crash and returned safe fallback
    expect(result).toBeDefined();
    expect(result.conversationId).toBeDefined();
    expect(result.safetyCategory).toBe('A');
    expect(result.content).toContain('connectivity issues');
    expect(result.proposals).toHaveLength(0);

    // Verify conversation was persisted with degraded message
    const convData = await orchestrator.getConversation(testUserId, result.conversationId);
    expect(convData).not.toBeNull();
    expect(convData!.messages.length).toBeGreaterThanOrEqual(2); // user + assistant

    gatewaySpy.mockRestore();
  });

  it('Provider Outage Drill (Arabic): Graceful degradation respects Arabic language and locale', async () => {
    const orchestrator = new AssistantOrchestrator();

    const gatewaySpy = vi.spyOn((orchestrator as any).gateway, 'execute').mockRejectedValueOnce(
      new Error('AI Gateway Error: 504 Gateway Timeout')
    );

    const result = await orchestrator.chat(
      testUserId,
      { message: 'كم يبلغ وزني اليوم وما هي خطتي؟' },
      'corr-outage-drill-arabic'
    );

    expect(result).toBeDefined();
    expect(result.content).toContain('صعوبة مؤقتة في الاتصال');
    expect(result.safetyCategory).toBe('A');

    gatewaySpy.mockRestore();
  });

  it('Database Outage Drill: GET /health/ready returns HTTP 503 when database is unreachable', async () => {
    // Spy on checkDatabaseHealth to simulate DB dropout
    const dbHealthSpy = vi.spyOn(dbModule, 'checkDatabaseHealth').mockResolvedValueOnce(false);

    const res = await app.inject({
      method: 'GET',
      url: '/health/ready'
    });

    expect(res.statusCode).toBe(503);
    const body = JSON.parse(res.payload);
    expect(body.status).toBe('unhealthy');
    expect(body.database).toBe('disconnected');
    expect(body.timestamp).toBeDefined();

    dbHealthSpy.mockRestore();
  });

  it('Transaction Rollback Drill: Atomic rollback leaves zero orphan records on partial failure', async () => {
    const uniqueActor = 'actor-rollback-drill-' + Date.now();

    // Execute transaction that intentionally fails halfway through
    let errorThrown = false;
    try {
      await withUserContext(testUserId, async (client) => {
        // Step 1: Insert a provenance record
        await client.query(
          `INSERT INTO provenance_records (
            user_id, origin_type, epistemic_class, actor, method_version,
            confidence_score, review_state, observed_at
          ) VALUES ($1, 'user_manual', 'direct_measurement', $2, '1.0', 1.0, 'unreviewed', NOW())`,
          [testUserId, uniqueActor]
        );

        // Step 2: Simulate downstream failure or constraint violation
        throw new Error('Simulated database deadlock / constraint violation');
      });
    } catch (err: any) {
      errorThrown = true;
      expect(err.message).toContain('Simulated database deadlock');
    }

    expect(errorThrown).toBe(true);

    // Verify provenance record was completely rolled back and DOES NOT exist in DB
    await withUserContext(testUserId, async (client) => {
      const checkRes = await client.query(
        `SELECT * FROM provenance_records WHERE user_id = $1 AND actor = $2`,
        [testUserId, uniqueActor]
      );
      expect(checkRes.rows).toHaveLength(0);
    });
  });

  it('Token Budget Bounds Drill: ContextEngine strictly adheres to token budget under massive input', async () => {
    const contextEngine = new AIContextEngine({
      snapshotService: new AnalyticsService(),
      measurementsService: MeasurementsService,
      goalsService: new GoalsService()
    });

    // Generate massive prompt (10,000 words)
    const massivePrompt = 'I want to track my macros and fitness. '.repeat(2000);
    expect(massivePrompt.length).toBeGreaterThan(40000);

    const bundle = await contextEngine.assembleContext(testUserId, massivePrompt);

    expect(bundle).toBeDefined();
    expect(bundle.manifest).toBeDefined();
    expect(bundle.systemContextText).toBeDefined();
    // System context must remain reasonably bounded (not exploding with raw payload)
    expect(bundle.systemContextText.length).toBeLessThan(30000);
  });
});
