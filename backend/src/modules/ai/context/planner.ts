import { ContextTier, IntentClass } from './types.js';

export class ContextPlanner {
  public static planIntentAndTier(userPrompt: string): {
    intent: IntentClass;
    tier: ContextTier;
    requiredDataTypes: string[];
  } {
    const text = userPrompt.toLowerCase().trim();

    // 1. General knowledge (Tier 0 - No user data needed)
    if (
      text.startsWith('what is') ||
      text.startsWith('explain how') ||
      text.includes('definition of') ||
      text.includes('why do humans') ||
      text.includes('what causes muscle soreness')
    ) {
      if (!text.includes('my') && !text.includes('i ') && !text.includes('me ')) {
        return {
          intent: 'general',
          tier: 0,
          requiredDataTypes: [],
        };
      }
    }

    // 2. Calculation request (Tier 2 - requires profile & metrics)
    if (
      text.includes('how many calories') ||
      text.includes('calculate my bmr') ||
      text.includes('calculate my tdee') ||
      text.includes('what is my bmi')
    ) {
      return {
        intent: 'calculation',
        tier: 2,
        requiredDataTypes: ['profile', 'weight'],
      };
    }

    // 3. Comparison / Historical trends (Tier 2)
    if (
      text.includes('compare with') ||
      text.includes('last month') ||
      text.includes('trend over time') ||
      text.includes('how much have i lost since')
    ) {
      return {
        intent: 'comparison',
        tier: 2,
        requiredDataTypes: ['observations', 'snapshot'],
      };
    }

    // 4. Data lookup / Current state (Tier 1 - Snapshot sufficient)
    if (
      text.includes('current weight') ||
      text.includes('my goal') ||
      text.includes('how am i doing') ||
      text.includes('what is my target') ||
      text.includes('my progress')
    ) {
      return {
        intent: 'data_lookup',
        tier: 1,
        requiredDataTypes: ['snapshot'],
      };
    }

    // 5. Guidance / Advice (Tier 1 by default, snapshot grounded)
    if (
      text.includes('should i') ||
      text.includes('what should i eat') ||
      text.includes('suggest a plan') ||
      text.includes('how to improve')
    ) {
      return {
        intent: 'guidance',
        tier: 1,
        requiredDataTypes: ['snapshot'],
      };
    }

    // Default: Tier 1 (Snapshot)
    return {
      intent: 'data_lookup',
      tier: 1,
      requiredDataTypes: ['snapshot'],
    };
  }
}
