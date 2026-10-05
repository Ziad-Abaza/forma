import { AIGateway } from '../gateway/gateway.js';
import { SafetyCategory } from './classifier.js';

export interface LLMSafetyResult {
  category: SafetyCategory;
  reason?: string;
}

export class LLMSafetyClassifier {
  /**
   * Fast, bounded second-pass LLM safety classification for subtle/paraphrased inputs (Spec §4.1 G-S3).
   * Runs with bounded timeout (2500ms) and fails closed to Category B if it errors or times out.
   */
  public static async classify(
    userPrompt: string,
    gateway: AIGateway
  ): Promise<LLMSafetyResult> {
    const prompt = `You are a strict safety classifier for a fitness & wellness app.
Analyze the user prompt and classify it into exactly one safety category:
- Category D: Acute emergency medical symptoms (e.g. chest pain, fainting, stroke signs, vomiting blood) OR eating disorder / severe starvation behaviors (e.g. purge, extreme caloric restriction <600 kcal, starvation).
- Category B: Nutrition, diet, caloric intake, metabolic guidance.
- Category C: General educational health / fitness knowledge.
- Category A: General safe fitness / habit coaching.

Return strictly a JSON object:
{"category": "A" | "B" | "C" | "D", "reason": "concise explanation"}

User Prompt: "${userPrompt.replace(/"/g, '\\"')}"`;

    const timeoutPromise = new Promise<LLMSafetyResult>((resolve) => {
      setTimeout(() => {
        // Safe timeout fallback
        resolve({ category: 'B', reason: 'LLM safety classifier timed out (fail closed)' });
      }, 2500);
    });

    const executionPromise = (async (): Promise<LLMSafetyResult> => {
      try {
        const execution = await gateway.execute('intent_classification', {
          prompt,
          temperature: 0.0,
          maxTokens: 80,
          responseJsonSchema: {
            type: 'object',
            properties: {
              category: { type: 'string', enum: ['A', 'B', 'C', 'D'] },
              reason: { type: 'string' }
            },
            required: ['category']
          }
        });

        const rawText = execution.result.text.trim();
        const jsonMatch = rawText.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
          const parsed = JSON.parse(jsonMatch[0]);
          const cat = parsed.category?.toUpperCase();
          if (['A', 'B', 'C', 'D'].includes(cat)) {
            return {
              category: cat as SafetyCategory,
              reason: parsed.reason || 'LLM classified'
            };
          }
        }
        return { category: 'B', reason: 'LLM response unparseable (fail closed to guarded)' };
      } catch (err: any) {
        return { category: 'B', reason: `LLM safety error: ${err.message}` };
      }
    })();

    return Promise.race([executionPromise, timeoutPromise]);
  }
}
