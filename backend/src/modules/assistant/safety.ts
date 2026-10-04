/**
 * AI Assistant Safety Classifier & Anti-Hallucination Envelope (§10.6.1, §10.8)
 *
 * Rules:
 * - Deterministic safety classification: Wellness, Nutrition, Educational, Concern-redirect.
 * - Concern signals (chest pain, fainting, extreme restriction, pregnancy, eating disorder signals) trigger Redirect.
 * - Anti-hallucination envelope: Numeric claims verified against tool output records.
 */

export type SafetyCategory =
  | 'wellness_fitness'
  | 'nutrition_guidance'
  | 'educational'
  | 'concern_redirect';

export interface SafetyClassificationResult {
  category: SafetyCategory;
  isRedirectRequired: boolean;
  redirectReason?: string;
  emergencyGuidance?: { en: string; ar: string };
}

export class SafetyClassifier {
  private static CONCERN_KEYWORDS = [
    'chest pain',
    'fainting',
    'pass out',
    'dizziness',
    'heart palpitations',
    'starving myself',
    'throwing up food',
    'purge',
    'anorexia',
    'bulimia',
    'pregnant',
    'breastfeeding',
  ];

  static classify(userPrompt: string): SafetyClassificationResult {
    const text = userPrompt.toLowerCase();

    for (const kw of this.CONCERN_KEYWORDS) {
      if (text.includes(kw)) {
        return {
          category: 'concern_redirect',
          isRedirectRequired: true,
          redirectReason: `Detected clinical concern or disordered-eating signal: "${kw}"`,
          emergencyGuidance: {
            en: 'Please consult a qualified medical professional immediately or contact emergency health services.',
            ar: 'يرجى مراجعة طبيب مختص فوراً أو الاتصال بخدمات الطوارئ الطبية المحلية.',
          },
        };
      }
    }

    if (text.includes('eat') || text.includes('calorie') || text.includes('macro') || text.includes('diet')) {
      return { category: 'nutrition_guidance', isRedirectRequired: false };
    }

    if (text.includes('what is') || text.includes('explain') || text.includes('how does')) {
      return { category: 'educational', isRedirectRequired: false };
    }

    return { category: 'wellness_fitness', isRedirectRequired: false };
  }
}

export class OutputValidator {
  /**
   * Verify numeric claims in AI assistant response against tool outputs.
   */
  static verifyNumericGrounding(
    aiContent: string,
    toolOutputNumbers: number[]
  ): {
    isGrounded: boolean;
    unmatchedNumbers: number[];
  } {
    // Extract numbers from text
    const matches = aiContent.match(/\b\d+(\.\d+)?\b/g);
    if (!matches) {
      return { isGrounded: true, unmatchedNumbers: [] };
    }

    const foundNumbers = matches.map((m) => parseFloat(m));
    const unmatchedNumbers: number[] = [];

    for (const num of foundNumbers) {
      // Allow minor integers (e.g. 1, 2, 3) or verify against tool results
      if (num <= 5) continue; // Skip list indices
      const isKnown = toolOutputNumbers.some((t) => Math.abs(t - num) < 0.15);
      if (!isKnown) {
        unmatchedNumbers.push(num);
      }
    }

    return {
      isGrounded: unmatchedNumbers.length === 0,
      unmatchedNumbers,
    };
  }
}
