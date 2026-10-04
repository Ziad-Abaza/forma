import { describe, it, expect } from 'vitest';
import { ActionProtocolService } from './action_protocol.js';
import { SafetyClassifier, OutputValidator } from './safety.js';

describe('Phase 4 AI Assistant & Controlled Actions (ADR-008, §10.6.1, §10.8)', () => {
  it('enforces Propose -> Confirm -> Commit workflow with receipts', () => {
    // 1. Model emits Action Proposal
    const proposal = ActionProtocolService.createProposal({
      userId: 'u_user_99',
      actionType: 'save_measurement',
      description: { en: 'Save weight as 81.5 kg', ar: 'حفظ الوزن كـ 81.5 كجم' },
      diffPreview: { weight: { before: 82.0, after: 81.5 } },
      payload: { value: 81.5, unit: 'kg', typeCode: 'weight' },
    });

    expect(proposal.id.startsWith('prop_')).toBe(true);
    expect(proposal.status).toBe('pending');
    expect(proposal.singleUseToken.length).toBeGreaterThan(20);

    // 2. Reject unauthorized confirmation attempt
    expect(() =>
      ActionProtocolService.confirmProposal(
        proposal.id,
        'other_user_attacker',
        proposal.singleUseToken,
        () => 'obs_saved_1'
      )
    ).toThrowError(/Unauthorized/);

    // 3. Reject confirmation with wrong token
    expect(() =>
      ActionProtocolService.confirmProposal(
        proposal.id,
        'u_user_99',
        'invalid_token',
        () => 'obs_saved_1'
      )
    ).toThrowError(/Invalid single-use confirmation token/);

    // 4. Successful confirmation by authenticated user
    const receipt = ActionProtocolService.confirmProposal(
      proposal.id,
      'u_user_99',
      proposal.singleUseToken,
      (payload) => 'obs_saved_1'
    );

    expect(receipt.receiptId.startsWith('rcpt_')).toBe(true);
    expect(receipt.status).toBe('committed');
    expect(receipt.committedRecordId).toBe('obs_saved_1');

    // 5. Subsequent confirmation is rejected (single-use)
    expect(() =>
      ActionProtocolService.confirmProposal(
        proposal.id,
        'u_user_99',
        proposal.singleUseToken,
        () => 'obs_saved_2'
      )
    ).toThrowError(/cannot confirm/);
  });

  it('classifies health safety concerns and triggers redirect mode', () => {
    const safeQuery = SafetyClassifier.classify('Can you suggest a good chest workout routine?');
    expect(safeQuery.category).toBe('wellness_fitness');
    expect(safeQuery.isRedirectRequired).toBe(false);

    const concernQuery = SafetyClassifier.classify('I have severe chest pain during my cardio');
    expect(concernQuery.category).toBe('concern_redirect');
    expect(concernQuery.isRedirectRequired).toBe(true);
    expect(concernQuery.emergencyGuidance?.en).toContain('qualified medical professional');
    expect(concernQuery.emergencyGuidance?.ar).toContain('طبيب مختص');
  });

  it('validates numeric claims against tool output ground truths', () => {
    const toolNumbers = [1780, 2450, 80.5]; // BMR, TDEE, Weight
    const validAiResponse = 'Your maintenance calories are 2450 kcal and your weight is 80.5 kg.';
    const validation = OutputValidator.verifyNumericGrounding(validAiResponse, toolNumbers);
    expect(validation.isGrounded).toBe(true);
    expect(validation.unmatchedNumbers).toHaveLength(0);

    const hallucinatedResponse = 'Your maintenance calories are 3200 kcal and you should eat 1400 kcal.';
    const hallucinationCheck = OutputValidator.verifyNumericGrounding(hallucinatedResponse, toolNumbers);
    expect(hallucinationCheck.isGrounded).toBe(false);
    expect(hallucinationCheck.unmatchedNumbers).toContain(3200);
    expect(hallucinationCheck.unmatchedNumbers).toContain(1400);
  });
});
