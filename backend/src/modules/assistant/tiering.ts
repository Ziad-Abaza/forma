// Response Tiering heuristics and configuration (Spec §2.1)
//
// Routing is an explicit ordered rule table: the first matching rule wins.
// The final entry is the unconditional T1 default — every prompt maps to a
// real tier; nothing falls through to an implicit/undefined tier.

export type ResponseTier = 'T0' | 'T1' | 'T2' | 'T3';

export interface TierConfig {
  tier: ResponseTier;
  maxTokens: number;
  temperature: number;
  maxWords: number;
}

interface TierRule {
  tier: ResponseTier;
  /** Human-readable rationale for audit/debugging. */
  rationale: string;
  matches: (text: string, wordCount: number, intentClass?: string) => boolean;
}

const PLAN_KEYWORDS = /\b(plan|program|schedule|routine|خطة|برنامج|جدول)\b/i;
const GREETINGS = /^(hi|hello|hey|thanks|thank you|yes|no|ok|مرحبا|اهلا|شكرا|نعم|لا)$/i;
const DETAILED_KEYWORDS = /\b(compare|progress|review|history|trend|difference|month|week|قارن|مقارنة|تقدم|تاريخ|تقرير|شهر)\b/i;

export const TIER_CONFIGS: Record<ResponseTier, TierConfig> = {
  T0: { tier: 'T0', maxTokens: 150, temperature: 0.3, maxWords: 40 },
  T1: { tier: 'T1', maxTokens: 400, temperature: 0.3, maxWords: 120 },
  T2: { tier: 'T2', maxTokens: 900, temperature: 0.3, maxWords: 350 },
  T3: { tier: 'T3', maxTokens: 1400, temperature: 0.5, maxWords: 600 }
};

/** Ordered most-specific → most-general. First match wins. */
const TIER_RULES: TierRule[] = [
  {
    tier: 'T3',
    rationale: 'plan/program request or explicit complex_analysis intent',
    matches: (text, _wc, intent) => PLAN_KEYWORDS.test(text) || intent === 'complex_analysis'
  },
  {
    tier: 'T0',
    rationale: 'greeting/acknowledgement or ≤3-word statement without a question',
    matches: (text, wordCount) => GREETINGS.test(text) || (wordCount <= 3 && !text.includes('?'))
  },
  {
    tier: 'T2',
    rationale: 'comparison/progress keywords, multiple questions, or long prompt',
    matches: (text, wordCount) =>
      DETAILED_KEYWORDS.test(text) ||
      (text.match(/\?|؟/g) || []).length >= 2 ||
      wordCount > 18
  }
];

export class TierSelector {
  public static selectTier(userPrompt: string, intentClass?: string): TierConfig {
    const text = userPrompt.toLowerCase().trim();
    const wordCount = text.split(/\s+/).length;

    for (const rule of TIER_RULES) {
      if (rule.matches(text, wordCount, intentClass)) {
        return TIER_CONFIGS[rule.tier];
      }
    }
    // T1 Standard: single how/why question, one-metric interpretation.
    return TIER_CONFIGS.T1;
  }
}
