// Response Tiering heuristics and configuration (Spec §2.1)

export type ResponseTier = 'T0' | 'T1' | 'T2' | 'T3';

export interface TierConfig {
  tier: ResponseTier;
  maxTokens: number;
  temperature: number;
  maxWords: number;
}

export class TierSelector {
  public static selectTier(userPrompt: string, intentClass?: string): TierConfig {
    const text = userPrompt.toLowerCase().trim();
    const wordCount = text.split(/\s+/).length;

    // Check T3 Plan keywords
    const planKeywords = /\b(plan|program|schedule|routine|خطة|برنامج|جدول)\b/i;
    if (planKeywords.test(text) || intentClass === 'complex_analysis') {
      return {
        tier: 'T3',
        maxTokens: 1400,
        temperature: 0.5,
        maxWords: 600
      };
    }

    // Check T0 Micro: greetings, thanks, short simple queries
    const greetings = /^(hi|hello|hey|thanks|thank you|yes|no|ok|مرحبا|اهلا|شكرا|نعم|لا)$/i;
    if (greetings.test(text) || (wordCount <= 3 && !text.includes('?'))) {
      return {
        tier: 'T0',
        maxTokens: 150,
        temperature: 0.3,
        maxWords: 40
      };
    }

    // Check T2 Detailed: comparison, multi-part, progress reviews
    const detailedKeywords = /\b(compare|progress|review|history|trend|difference|month|week|قارن|مقارنة|تقدم|تاريخ|تقرير|شهر)\b/i;
    const hasMultipleQuestions = (text.match(/\?|؟/g) || []).length >= 2;
    if (detailedKeywords.test(text) || hasMultipleQuestions || wordCount > 18) {
      return {
        tier: 'T2',
        maxTokens: 900,
        temperature: 0.3,
        maxWords: 350
      };
    }

    // Default T1 Standard: single how/why question, one-metric interpretation
    return {
      tier: 'T1',
      maxTokens: 400,
      temperature: 0.3,
      maxWords: 120
    };
  }
}
