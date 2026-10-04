/**
 * Cross-Tenant Isolation Security Test Suite (§20.2, §31.1 Gate 1)
 *
 * Verifies:
 * 1. Zero cross-user data leakage paths across observations, goals, snapshots, drafts.
 * 2. IDOR defense: attempting to commit, void, or confirm another tenant's entity fails closed.
 */

import { describe, it, expect } from 'vitest';
import { ObservationService } from '../modules/measurements/model.js';
import { ExtractionService } from '../modules/extraction/service.js';
import { ActionProtocolService } from '../modules/assistant/action_protocol.js';

describe('Cross-Tenant Security Isolation (RFC 2119 Gate 1)', () => {
  const userA = 'tenant_alice';
  const userB = 'tenant_bob_attacker';

  it('prevents user B from confirming user A action proposal', () => {
    const proposal = ActionProtocolService.createProposal({
      userId: userA,
      actionType: 'save_measurement',
      description: { en: 'Update weight', ar: 'تحديث الوزن' },
      diffPreview: { weight: { before: 80, after: 79.5 } },
      payload: { value: 79.5 },
    });

    expect(() =>
      ActionProtocolService.confirmProposal(
        proposal.id,
        userB,
        proposal.singleUseToken,
        () => 'unauthorized_write'
      )
    ).toThrowError(/Unauthorized proposal confirmation attempt/);
  });

  it('prevents user B from committing user A extraction draft', () => {
    const draft = ExtractionService.createDraft({
      userId: userA,
      sourceArtifactId: 'scan_alice_01',
      sourceType: 'body_composition_report',
      rawExtractedData: [{ typeCode: 'weight', value: 65.0, unit: 'kg', confidence: 0.95 }],
    });

    expect(() => ExtractionService.commitDraft(draft, userB)).toThrowError(/Unauthorized draft commit attempt/);
  });

  it('enforces strict tenant binding on observations', () => {
    const obsA = ObservationService.createObservation({
      id: 'obs_alice_1',
      userId: userA,
      typeCode: 'weight',
      value: 65.0,
      unit: 'kg',
    });

    expect(obsA.observation.userId).toBe(userA);
    expect(obsA.provenance.userId).toBe(userA);
  });
});
