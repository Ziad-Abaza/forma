import type { EvidenceClaim, EvidenceType } from './contracts.js';

export interface GroundingContext {
  snapshot?: Record<string, any>;
  toolOutputs?: Array<{ toolName: string; result: any }>;
}

export class EvidenceClaimVerifier {
  private static readonly NUMERIC_CLAIM_REGEX = /(\b\d+(?:\.\d+)?\s*(?:kg|lbs?|cm|m|kcal|calories|bpm|%|steps|hours?|min|كجم|كيلو|سم|سعرة)?\b)/gi;

  /**
   * Scans generated assistant response text, extracts claims and validates them
   * against the grounding context (tools invoked & snapshot records).
   */
  static extractAndVerifyClaims(
    text: string,
    grounding: GroundingContext
  ): EvidenceClaim[] {
    const claims: EvidenceClaim[] = [];
    const knownValues = this.collectKnownValues(grounding);

    // 1. Look for explicit tags in markdown like [Retrieved: weight = 75 kg] or [Calculated: BMI = 23.5]
    const explicitTagRegex = /\[(Retrieved|Calculated|Estimated|Inferred|Recommended)(?::\s*([^\]]+))?\]/gi;
    let match: RegExpExecArray | null;

    while ((match = explicitTagRegex.exec(text)) !== null) {
      const tag = match[1];
      if (!tag) continue;
      const tagType = tag.toLowerCase() as EvidenceType;
      const detail = match[2] ? match[2].trim() : match[0];
      claims.push({
        claimText: detail,
        evidenceType: tagType,
        source: 'explicit_annotation'
      });
    }

    // 2. Scan for numeric claims and match against known values
    const numericMatches = text.match(this.NUMERIC_CLAIM_REGEX) || [];
    for (const rawNumber of numericMatches) {
      const numericVal = parseFloat(rawNumber.replace(/[^\d.]/g, ''));
      if (isNaN(numericVal)) continue;

      const matchingFact = knownValues.find(f => Math.abs(f.value - numericVal) < 0.05);

      if (matchingFact) {
        // Prevent duplicate claims for the same text
        if (!claims.some(c => c.claimText.includes(rawNumber))) {
          claims.push({
            claimText: rawNumber,
            evidenceType: matchingFact.type,
            source: matchingFact.source,
            value: numericVal
          });
        }
      } else {
        // Numeric value not found in verified tool output or snapshot
        // Check if context suggests recommendation
        const isRecommendation = /target|goal|aim|recommend|suggest/i.test(text);
        claims.push({
          claimText: rawNumber,
          evidenceType: isRecommendation ? 'recommended' : 'unknown',
          source: isRecommendation ? 'assistant_guidance' : 'unverified',
          value: numericVal
        });
      }
    }

    return claims;
  }

  /**
   * Extracts ground truth facts and metrics from snapshot and tool execution outputs.
   */
  private static collectKnownValues(
    grounding: GroundingContext
  ): Array<{ value: number; type: EvidenceType; source: string }> {
    const facts: Array<{ value: number; type: EvidenceType; source: string }> = [];

    // From Snapshot
    if (grounding.snapshot) {
      const snap = grounding.snapshot;

      // Body Status / Identity
      if (snap.bodyStatus) {
        if (snap.bodyStatus.latestWeightKg) {
          facts.push({ value: snap.bodyStatus.latestWeightKg, type: 'retrieved', source: 'snapshot.weight' });
        }
        if (snap.bodyStatus.latestHeightCm) {
          facts.push({ value: snap.bodyStatus.latestHeightCm, type: 'retrieved', source: 'snapshot.height' });
        }
        if (snap.bodyStatus.currentBmi) {
          facts.push({ value: snap.bodyStatus.currentBmi, type: 'calculated', source: 'snapshot.bmi' });
        }
      }

      // Energy
      if (snap.energy) {
        if (snap.energy.bmr) facts.push({ value: snap.energy.bmr, type: 'calculated', source: 'snapshot.bmr' });
        if (snap.energy.tdee) facts.push({ value: snap.energy.tdee, type: 'calculated', source: 'snapshot.tdee' });
        if (snap.energy.targetCalories) facts.push({ value: snap.energy.targetCalories, type: 'recommended', source: 'snapshot.targetCalories' });
      }

      // Recent measurements
      if (Array.isArray(snap.recentMeasurements)) {
        for (const m of snap.recentMeasurements) {
          if (m && typeof m.value === 'number') {
            facts.push({ value: m.value, type: 'retrieved', source: `measurement.${m.typeCode || 'unknown'}` });
          }
        }
      }
    }

    // From Tool Execution Outputs
    if (grounding.toolOutputs) {
      for (const item of grounding.toolOutputs) {
        if (!item.result) continue;
        const res = item.result;

        if (typeof res === 'object') {
          for (const [k, v] of Object.entries(res)) {
            if (typeof v === 'number') {
              const evidenceType: EvidenceType =
                k.includes('bmi') || k.includes('bmr') || k.includes('tdee')
                  ? 'calculated'
                  : k.includes('target') || k.includes('recommended')
                  ? 'recommended'
                  : 'retrieved';
              facts.push({ value: v, type: evidenceType, source: `${item.toolName}.${k}` });
            }
          }
        }
      }
    }

    return facts;
  }
}
