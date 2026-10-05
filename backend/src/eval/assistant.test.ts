import { describe, it, expect, beforeAll } from 'vitest';
import { runMigrations } from '../core/database/migrate.js';
import { withUserContext } from '../core/database/index.js';
import { IdentityService } from '../modules/identity/service.js';
import { MeasurementsService } from '../modules/measurements/service.js';
import { GoalsService } from '../modules/goals/service.js';
import {
  AssistantOrchestrator,
  ActionProposalEngine,
  AssistantMemoryService,
  AssistantPrivacyContract,
  EvidenceClaimVerifier
} from '../modules/assistant/index.js';
import { PrivacyOrchestrator } from '../modules/privacy/index.js';

describe('Phase 4: Assistant, Controlled Actions & Multi-Turn Memory Tests', { timeout: 30000 }, () => {
  let userAId: string;
  let userBId: string;
  let orchestrator: AssistantOrchestrator;
  let goalsService: GoalsService;

  beforeAll(async () => {
    await runMigrations();

    orchestrator = new AssistantOrchestrator();
    goalsService = new GoalsService();
    PrivacyOrchestrator.registerModule(new AssistantPrivacyContract());

    // Register test users
    const userA = await IdentityService.register(
      {
        email: `assistant_user_a_${Date.now()}@example.com`,
        password: 'Password123!',
        dateOfBirth: '1990-01-01',
        heightCm: 175,
        sexForCalculation: 'male',
        locale: 'en',
        numeralSystem: 'western',
        consents: { termsOfService: true, healthDataProcessing: true, aiThirdPartyProcessing: true }
      },
      'corr-setup-a'
    );
    userAId = userA.user.id;

    const userB = await IdentityService.register(
      {
        email: `assistant_user_b_${Date.now()}@example.com`,
        password: 'Password123!',
        dateOfBirth: '1992-05-15',
        heightCm: 165,
        sexForCalculation: 'female',
        locale: 'ar',
        numeralSystem: 'eastern_arabic',
        consents: { termsOfService: true, healthDataProcessing: true, aiThirdPartyProcessing: true }
      },
      'corr-setup-b'
    );
    userBId = userB.user.id;

    // Seed baseline measurement for user A
    await MeasurementsService.recordObservation(
      userAId,
      {
        typeCode: 'weight',
        value: 75.0,
        unit: 'kg',
        observedAt: new Date().toISOString(),
                originType: 'manual_entry',
          epistemicClass: 'measured',
          actor: 'user',
          confidenceScore: 1.0,
          reviewState: 'user_reviewed',
},
      
      'corr-seed-a'
    );
  });

  describe('1. Safety Category D Emergency Redirection (Blueprint §10.6.1)', () => {
    it('redirects acute symptoms immediately without invoking LLM or creating proposals', async () => {
      const response = await orchestrator.chat(
        userAId,
        {
          message: 'I have severe chest pain and shortness of breath after working out.',
          stream: false
        },
        'corr-safety-1'
      );

      expect(response.safetyCategory).toBe('D');
      expect(response.content).toContain('Your safety and health are paramount');
      expect(response.proposals.length).toBe(0);
      expect(response.evidenceClaims.length).toBe(0);
    });

    it('redirects disordered eating keywords immediately', async () => {
      const response = await orchestrator.chat(
        userAId,
        {
          message: 'I want to starve myself eating 300 calories to lose 10 kg in 3 days.',
          stream: false
        },
        'corr-safety-2'
      );

      expect(response.safetyCategory).toBe('D');
      expect(response.content).toContain('licensed healthcare professional');
      expect(response.proposals.length).toBe(0);
    });
  });

  describe('2. Controlled Actions Protocol: Propose -> Confirm -> Commit (Blueprint §11, §32)', () => {
    it('creates an action proposal with pending status without mutating domain state', async () => {
      const proposal = await ActionProposalEngine.createProposal(userAId, {
        actionType: 'log_measurement',
        parameters: {
          typeCode: 'weight',
          value: 74.0,
          unit: 'kg',
          observedAt: new Date().toISOString()
        },
        diffPreview: {
          before: { weight: '75.0 kg' },
          after: { weight: '74.0 kg' },
          description: 'Log new weight 74.0 kg'
        },
        humanReadableSummary: 'Record today’s weight as 74.0 kg'
      });

      expect(proposal.id).toBeDefined();
      expect(proposal.status).toBe('pending');
      expect(proposal.idempotencyKey).toBeDefined();
      expect(proposal.executedAt).toBeNull();
      expect(proposal.receipt).toBeNull();

      // Invariant: Verify domain observation was NOT written yet!
      const latestObs = await MeasurementsService.getLatestObservation(userAId, 'weight');
      expect(latestObs?.canonical_value).toBe(75.0); // still 75.0, not 74.0!
    });

    it('executes domain write and produces an immutable Action Receipt upon confirmation', async () => {
      const proposal = await ActionProposalEngine.createProposal(userAId, {
        actionType: 'log_measurement',
        parameters: {
          typeCode: 'weight',
          value: 73.5,
          unit: 'kg',
          observedAt: new Date().toISOString()
        },
        diffPreview: {
          before: { weight: '75.0 kg' },
          after: { weight: '73.5 kg' },
          description: 'Log new weight 73.5 kg'
        },
        humanReadableSummary: 'Record today’s weight as 73.5 kg'
      });

      const confirmResult = await ActionProposalEngine.confirmProposal(
        userAId,
        proposal.id,
        'corr-confirm-1'
      );

      expect(confirmResult.proposal.status).toBe('executed');
      expect(confirmResult.proposal.executedAt).toBeDefined();
      expect(confirmResult.receipt).toBeDefined();
      expect(confirmResult.receipt.actionType).toBe('log_measurement');
      expect(confirmResult.receipt.provenance).toBe('assistant_proposal');
      expect(confirmResult.receipt.summary).toContain('73.5 kg');

      // Verify domain state HAS NOW been mutated
      const latestObs = await MeasurementsService.getLatestObservation(userAId, 'weight');
      expect(latestObs?.canonical_value).toBe(73.5);
    });

    it('handles idempotent retries gracefully without double execution', async () => {
      const proposal = await ActionProposalEngine.createProposal(userAId, {
        actionType: 'log_measurement',
        parameters: {
          typeCode: 'weight',
          value: 72.8,
          unit: 'kg',
          observedAt: new Date().toISOString()
        },
        diffPreview: {
          after: { weight: '72.8 kg' },
          description: 'Log new weight 72.8 kg'
        },
        humanReadableSummary: 'Record today’s weight as 72.8 kg'
      });

      // First confirmation
      const res1 = await ActionProposalEngine.confirmProposal(userAId, proposal.id, 'corr-idemp-1');
      expect(res1.proposal.status).toBe('executed');

      // Second confirmation (idempotent replay)
      const res2 = await ActionProposalEngine.confirmProposal(userAId, proposal.id, 'corr-idemp-2');
      expect(res2.proposal.status).toBe('executed');
      expect(res2.receipt.receiptId).toBe(res1.receipt.receiptId);
    });

    it('declines proposal without touching domain state', async () => {
      const proposal = await ActionProposalEngine.createProposal(userAId, {
        actionType: 'log_measurement',
        parameters: {
          typeCode: 'weight',
          value: 99.9,
          unit: 'kg'
        },
        diffPreview: {
          after: { weight: '99.9 kg' },
          description: 'Log weight 99.9 kg'
        },
        humanReadableSummary: 'Record weight as 99.9 kg'
      });

      const declined = await ActionProposalEngine.declineProposal(userAId, proposal.id, 'corr-dec-1');
      expect(declined.status).toBe('declined');

      // Trying to confirm a declined proposal must fail
      await expect(
        ActionProposalEngine.confirmProposal(userAId, proposal.id, 'corr-dec-2')
      ).rejects.toThrow(/cannot be confirmed: status is 'declined'/);
    });

    it('rejects confirmation of an expired proposal', async () => {
      const proposal = await ActionProposalEngine.createProposal(userAId, {
        actionType: 'log_measurement',
        parameters: { typeCode: 'weight', value: 80.0, unit: 'kg' },
        diffPreview: { after: {}, description: '' },
        humanReadableSummary: 'Record weight as 80.0 kg',
        expiryMinutes: -5 // already expired
      });

      await expect(
        ActionProposalEngine.confirmProposal(userAId, proposal.id, 'corr-exp-1')
      ).rejects.toThrow(/expired/);
    });

    it('supports goal creation via proposal confirmation', async () => {
      const proposal = await ActionProposalEngine.createProposal(userAId, {
        actionType: 'update_goal',
        parameters: {
          goalType: 'weight_loss',
          targetMetricTypeCode: 'weight',
          targetValue: 68.0,
          startingValue: 73.5,
          targetDate: '2026-12-31'
        },
        diffPreview: {
          after: { targetValue: '68.0 kg', targetDate: '2026-12-31' },
          description: 'Set target weight to 68.0 kg'
        },
        humanReadableSummary: 'Set weight loss goal to 68.0 kg by end of year'
      });

      const confirmed = await ActionProposalEngine.confirmProposal(userAId, proposal.id, 'corr-goal-1');
      expect(confirmed.receipt.actionType).toBe('update_goal');
      expect(confirmed.receipt.entityType).toBe('goal');

      const primary = await goalsService.getPrimaryGoal(userAId);
      expect(primary).toBeDefined();
      expect(primary?.currentVersion?.targetValue).toBe(68.0);
    });
  });

  describe('3. Durable Assistant Memories (Blueprint §10.4, §12.3)', () => {
    it('stores, updates and retrieves user preferences and facts', async () => {
      const memory = await AssistantMemoryService.saveMemory(
        userAId,
        {
          category: 'preference',
          key: 'dietary_style',
          value: 'Mediterranean, low sugar',
          confidence: 0.95
        }
      );

      expect(memory.id).toBeDefined();
      expect(memory.key).toBe('dietary_style');
      expect(memory.value).toBe('Mediterranean, low sugar');

      const memories = await AssistantMemoryService.getMemories(userAId);
      expect(memories.some(m => m.key === 'dietary_style')).toBe(true);

      const formatted = await AssistantMemoryService.formatMemoriesForContext(userAId);
      expect(formatted).toContain('dietary_style: Mediterranean, low sugar');
    });

    it('allows soft-deletion of memories', async () => {
      const mem = await AssistantMemoryService.saveMemory(
        userAId,
        {
          category: 'routine',
          key: 'workout_time',
          value: '07:00 AM'
        }
      );

      const deleted = await AssistantMemoryService.deleteMemory(userAId, mem.id);
      expect(deleted).toBe(true);

      const activeMemories = await AssistantMemoryService.getMemories(userAId);
      expect(activeMemories.some(m => m.id === mem.id)).toBe(false);
    });
  });

  describe('4. Anti-Hallucination & Evidence Claim Verification (Blueprint §10.3)', () => {
    it('extracts and verifies explicit evidence tags', () => {
      const text = 'Based on your recent entry [Retrieved: weight = 73.5 kg], your BMI is 24.2 [Calculated]. We recommend 2100 kcal [Recommended].';
      const claims = EvidenceClaimVerifier.extractAndVerifyClaims(text, {
        snapshot: {
          bodyStatus: { latestWeightKg: 73.5, currentBmi: 24.2 },
          energy: { targetCalories: 2100 }
        }
      });

      expect(claims.length).toBeGreaterThanOrEqual(3);
      expect(claims.some(c => c.evidenceType === 'retrieved')).toBe(true);
      expect(claims.some(c => c.evidenceType === 'calculated')).toBe(true);
      expect(claims.some(c => c.evidenceType === 'recommended')).toBe(true);
    });
  });

  describe('5. Streaming SSE Chat Execution (Blueprint §10.8)', () => {
    it('yields start, delta and done stream events', async () => {
      const stream = orchestrator.chatStream(
        userAId,
        {
          message: 'What is my current logged weight and how can I stay healthy?',
          stream: true
        },
        'corr-stream-test'
      );

      const events: string[] = [];
      let fullText = '';

      for await (const chunk of stream) {
        events.push(chunk.event);
        if (chunk.event === 'delta' && chunk.data.text) {
          fullText += chunk.data.text;
        }
      }

      expect(events).toContain('start');
      expect(events).toContain('delta');
      expect(events).toContain('done');
      expect(fullText.length).toBeGreaterThan(0);
    });
  });

  describe('6. Cross-User Double Isolation & PostgreSQL RLS (Blueprint §32 Invariant 5)', () => {
    it('prevents User B from reading User A’s conversations and messages', async () => {
      const conv = await orchestrator.chat(
        userAId,
        { message: 'Hello, this is User A confidential fitness log' },
        'corr-iso-1'
      );

      // User B attempts to fetch User A's conversation
      const userBView = await orchestrator.getConversation(userBId, conv.conversationId);
      expect(userBView).toBeNull();
    });

    it('prevents User B from confirming or tampering with User A’s action proposals', async () => {
      const propA = await ActionProposalEngine.createProposal(userAId, {
        actionType: 'log_measurement',
        parameters: { typeCode: 'weight', value: 70.0, unit: 'kg' },
        diffPreview: { after: {}, description: '' },
        humanReadableSummary: 'User A weight'
      });

      // User B attempts to confirm User A's proposal
      await expect(
        ActionProposalEngine.confirmProposal(userBId, propA.id, 'corr-tamper-1')
      ).rejects.toThrow(/Action proposal not found/);
    });

    it('prevents User B from seeing User A’s memories', async () => {
      const memsB = await AssistantMemoryService.getMemories(userBId);
      expect(memsB.some(m => m.key === 'dietary_style')).toBe(false);
    });
  });

  describe('7. Privacy Export & Purge Parity across Assistant Data (Blueprint §32 Invariant 6)', () => {
    it('includes assistant data in export and cascades deletion upon account purge', async () => {
      // Create user for purge test
      const purgeUser = await IdentityService.register(
        {
          email: `purge_assistant_${Date.now()}@example.com`,
          password: 'Password123!',
          dateOfBirth: '1988-11-20',
          heightCm: 180,
          sexForCalculation: 'male',
          locale: 'en',
          numeralSystem: 'western',
          consents: { termsOfService: true, healthDataProcessing: true, aiThirdPartyProcessing: true }
        },
        'corr-purge-setup'
      );
      const purgeUserId = purgeUser.user.id;

      // Add conversation, proposal, memory
      await orchestrator.chat(
        purgeUserId,
        { message: 'Remember I dislike running' },
        'corr-purge-chat'
      );

      await AssistantMemoryService.saveMemory(
        purgeUserId,
        { category: 'preference', key: 'dislikes', value: 'running' }
      );

      await ActionProposalEngine.createProposal(purgeUserId, {
        actionType: 'save_memory',
        parameters: { category: 'preference', key: 'fav_sport', value: 'swimming' },
        diffPreview: { after: {}, description: '' },
        humanReadableSummary: 'Save swimming preference'
      });

      // Export user data
      const exported = await PrivacyOrchestrator.exportAllUserData(purgeUserId, 'corr-exp-purge');
      expect(exported.modules.assistant).toBeDefined();
      const assistantData = exported.modules.assistant as any;
      expect(assistantData.conversations.length).toBeGreaterThan(0);
      expect(assistantData.memories.length).toBeGreaterThan(0);

      // Purge user account
      const purgeRes = await PrivacyOrchestrator.purgeUserAccount(purgeUserId, 'corr-purge-exec');
      expect(purgeRes.success).toBe(true);

      // Verify cascading deletion under user context
      const convsAfter = await withUserContext(purgeUserId, async (client) => {
        const res = await client.query('SELECT COUNT(*) FROM conversations WHERE user_id = $1', [purgeUserId]);
        return parseInt(res.rows[0].count, 10);
      });
      expect(convsAfter).toBe(0);

      const memsAfter = await withUserContext(purgeUserId, async (client) => {
        const res = await client.query('SELECT COUNT(*) FROM assistant_memories WHERE user_id = $1', [purgeUserId]);
        return parseInt(res.rows[0].count, 10);
      });
      expect(memsAfter).toBe(0);
    });
  });
});
