// Safety Classification and Response Modes (Blueprint §10.6.1)

export type SafetyCategory = 'A' | 'B' | 'C' | 'D';
export type SafetyResponseMode = 'normal' | 'guarded' | 'redirect';

export interface SafetyClassificationResult {
  category: SafetyCategory;
  mode: SafetyResponseMode;
  guardrailsTriggered: string[];
  redirectMessage?: string | undefined;
}

export class SafetyClassifier {
  private static readonly EMERGENCY_KEYWORDS = [
    'chest pain',
    'fainting',
    'shortness of breath',
    'passed out',
    'blood in vomit',
    'severe dizziness',
    'heart palpitations',
  ];

  private static readonly DISORDERED_EATING_KEYWORDS = [
    'starve myself',
    'eating 300 calories',
    'purge after eating',
    'vomit after meals',
    'fasting for 3 weeks',
    'lose 10 kg in 3 days',
  ];

  public static classify(userPrompt: string): SafetyClassificationResult {
    const text = userPrompt.toLowerCase();
    const guardrailsTriggered: string[] = [];

    // Check Category D: Acute Medical Symptoms
    for (const kw of this.EMERGENCY_KEYWORDS) {
      if (text.includes(kw)) {
        guardrailsTriggered.push(`acute_symptom_${kw.replace(/\s+/g, '_')}`);
      }
    }

    // Check Category D: Disordered Eating / Extreme Restriction
    for (const kw of this.DISORDERED_EATING_KEYWORDS) {
      if (text.includes(kw)) {
        guardrailsTriggered.push(`disordered_eating_${kw.replace(/\s+/g, '_')}`);
      }
    }

    if (guardrailsTriggered.length > 0) {
      return {
        category: 'D',
        mode: 'redirect',
        guardrailsTriggered,
        redirectMessage:
          'Your safety and health are paramount. The symptoms or behaviors you described require immediate evaluation by a licensed healthcare professional or emergency medical services. Forma is an informational companion and does not provide medical treatment or diagnose conditions.',
      };
    }

    // Category C: General Education
    if (
      text.startsWith('what is') ||
      text.startsWith('explain') ||
      text.includes('definition')
    ) {
      if (!text.includes('my') && !text.includes('i ') && !text.includes('me ')) {
        return {
          category: 'C',
          mode: 'normal',
          guardrailsTriggered: [],
        };
      }
    }

    // Category B: Nutrition & Metabolic Guidance
    if (
      text.includes('calorie') ||
      text.includes('protein') ||
      text.includes('carb') ||
      text.includes('macro') ||
      text.includes('diet') ||
      text.includes('food') ||
      text.includes('bmr') ||
      text.includes('tdee') ||
      text.includes('سعرة') ||
      text.includes('بروتين') ||
      text.includes('غذاء') ||
      text.includes('أكل')
    ) {
      return {
        category: 'B',
        mode: 'normal',
        guardrailsTriggered: [],
      };
    }

    // Category A: Wellness/Fitness Guidance
    return {
      category: 'A',
      mode: 'normal',
      guardrailsTriggered: [],
    };
  }
}
