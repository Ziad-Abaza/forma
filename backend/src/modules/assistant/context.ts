/**
 * AI Context Engine & Data Budget (ADR-019, ADR-020, §11)
 *
 * Rules:
 * - Smallest sufficient context: Tier ladder 0 -> 4.
 * - AI Data Budget: Hard limits on tokens, records, tools, latency.
 * - Context Manifest: What was included/excluded and why (identifiers only, not values).
 * - Degradation ladder on budget exhaustion.
 */

export type ContextTier = 0 | 1 | 2 | 3 | 4;

export interface AiDataBudget {
  maxContextTokens: number;
  maxToolCalls: number;
  maxRecordsReturned: number;
  timeoutMs: number;
}

export const BUDGET_PROFILES: Record<string, AiDataBudget> = {
  general_qa: { maxContextTokens: 1000, maxToolCalls: 0, maxRecordsReturned: 0, timeoutMs: 5000 },
  quick_lookup: { maxContextTokens: 2500, maxToolCalls: 2, maxRecordsReturned: 10, timeoutMs: 8000 },
  structured_analysis: { maxContextTokens: 6000, maxToolCalls: 5, maxRecordsReturned: 50, timeoutMs: 15000 },
  deep_analysis: { maxContextTokens: 12000, maxToolCalls: 10, maxRecordsReturned: 200, timeoutMs: 30000 },
};

export interface ContextManifest {
  tier: ContextTier;
  includedSections: string[];
  excludedSections: string[];
  recordsCount: number;
  budgetConsumedTokens: number;
  watermark: string;
}

export class AiContextEngine {
  /**
   * Determine minimum sufficient context tier based on user query intent.
   */
  static planTier(userMessage: string): ContextTier {
    const query = userMessage.toLowerCase();

    // Tier 0: General knowledge / no user data
    if (query.includes('what is visceral fat') || query.includes('how does bmr work') || query.includes('hello')) {
      return 0;
    }

    // Tier 1: Current status / Snapshot only
    if (
      query.includes('how am i doing') ||
      query.includes('what is my current weight') ||
      query.includes('my targets') ||
      query.includes('calorie target')
    ) {
      return 1;
    }

    // Tier 2: Targeted comparison / series
    if (query.includes('compare with last month') || query.includes('what changed since') || query.includes('trend')) {
      return 2;
    }

    // Tier 3: Semantic / notes
    if (query.includes('what did i note') || query.includes('injury') || query.includes('doctor said')) {
      return 3;
    }

    // Tier 4: Deep cross-period analysis
    return 4;
  }

  /**
   * Assemble context within budget profile.
   */
  static assembleContext(tier: ContextTier, snapshotSections: Record<string, unknown>): {
    assembledContext: Record<string, unknown>;
    manifest: ContextManifest;
  } {
    const included: string[] = [];
    const excluded: string[] = [];
    const assembled: Record<string, unknown> = {};

    if (tier === 0) {
      return {
        assembledContext: {},
        manifest: {
          tier: 0,
          includedSections: [],
          excludedSections: Object.keys(snapshotSections),
          recordsCount: 0,
          budgetConsumedTokens: 50,
          watermark: `wm_${Date.now()}`,
        },
      };
    }

    // Tier 1+: Include relevant snapshot sections
    for (const [secName, secData] of Object.entries(snapshotSections)) {
      if (tier === 1 && (secName === 'identityLite' || secName === 'bodyStatus' || secName === 'primaryGoal')) {
        assembled[secName] = secData;
        included.push(secName);
      } else if (tier > 1) {
        assembled[secName] = secData;
        included.push(secName);
      } else {
        excluded.push(secName);
      }
    }

    return {
      assembledContext: assembled,
      manifest: {
        tier,
        includedSections: included,
        excludedSections: excluded,
        recordsCount: included.length,
        budgetConsumedTokens: 350 * included.length,
        watermark: `wm_${Date.now()}`,
      },
    };
  }
}
