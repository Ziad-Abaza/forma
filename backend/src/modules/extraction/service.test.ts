import { describe, it, expect } from 'vitest';
import { ExtractionService } from './service.js';

describe('Phase 5 Multimodal & Image Extraction (ADR-011, §13)', () => {
  it('creates an Extraction Draft with plausibility validation and confidence flags', () => {
    const draft = ExtractionService.createDraft({
      userId: 'user_vision_1',
      sourceArtifactId: 'art_inbody_scan_01',
      sourceType: 'body_composition_report',
      rawExtractedData: [
        { typeCode: 'weight', value: 82.4, unit: 'kg', confidence: 0.98 },
        { typeCode: 'body_fat_pct', value: 16.2, unit: 'percent', confidence: 0.94 },
        { typeCode: 'skeletal_muscle_mass', value: 39.5, unit: 'kg', confidence: 0.72 }, // low confidence
      ],
    });

    expect(draft.status).toBe('draft');
    expect(draft.fields).toHaveLength(3);

    // High confidence fields are approved by default for review
    expect(draft.fields[0].isApproved).toBe(true);
    expect(draft.fields[1].isApproved).toBe(true);

    // Low confidence field is flagged and requires attention
    expect(draft.fields[2].isApproved).toBe(false);
    expect(draft.fields[2].qualityFlags).toContain('low-confidence-attention-required');
  });

  it('commits approved fields into a measurement session with image provenance', () => {
    const draft = ExtractionService.createDraft({
      userId: 'user_vision_1',
      sourceArtifactId: 'art_inbody_scan_01',
      sourceType: 'body_composition_report',
      rawExtractedData: [
        { typeCode: 'weight', value: 82.4, unit: 'kg', confidence: 0.98 },
      ],
    });

    const commitResult = ExtractionService.commitDraft(draft, 'user_vision_1');

    expect(draft.status).toBe('committed');
    expect(commitResult.observations).toHaveLength(1);
    expect(commitResult.sessionId.startsWith('session_')).toBe(true);

    const obs = commitResult.observations[0];
    const prov = commitResult.provenances[0];

    expect(obs.canonicalValue).toBe(82.4);
    expect(obs.sessionId).toBe(commitResult.sessionId);
    expect(prov.originType).toBe('ai_extraction_image');
    expect(prov.sourceArtifactId).toBe('art_inbody_scan_01');
    expect(prov.actor.type).toBe('ai');
  });

  it('rejects unapproved or unauthorized draft commit attempts', () => {
    const draft = ExtractionService.createDraft({
      userId: 'user_vision_1',
      sourceArtifactId: 'art_scale_01',
      sourceType: 'smart_scale_display',
      rawExtractedData: [
        { typeCode: 'weight', value: 75.0, unit: 'kg', confidence: 0.6 }, // low confidence -> not approved
      ],
    });

    // Attempt commit without approving any field
    expect(() => ExtractionService.commitDraft(draft, 'user_vision_1')).toThrowError(/No fields approved/);

    // Approve field
    draft.fields[0].isApproved = true;

    // Reject unauthorized user
    expect(() => ExtractionService.commitDraft(draft, 'malicious_user')).toThrowError(/Unauthorized/);
  });
});
