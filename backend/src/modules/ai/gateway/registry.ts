import { ModelDefinition, TaskClass } from './types.js';

export class ModelRegistry {
  private static readonly models: Map<string, ModelDefinition> = new Map([
    [
      'gemini-3.8-flash',
      {
        id: 'gemini-3.8-flash',
        provider: 'google',
        displayName: 'Google Gemini 3.8 Flash',
        capabilities: ['text', 'vision', 'structured_output', 'tool_calling'],
        contextWindow: 1048576,
        maxOutputTokens: 8192,
        inputCostPerMillionUsd: 0.1,
        outputCostPerMillionUsd: 0.4,
        supportedLanguages: ['en', 'ar'],
        evalStatus: 'approved',
      },
    ],
    [
      'forma-secondary-text-v1',
      {
        id: 'forma-secondary-text-v1',
        provider: 'secondary',
        displayName: 'Forma Secondary Text Model',
        capabilities: ['text', 'structured_output', 'tool_calling'],
        contextWindow: 32768,
        maxOutputTokens: 4096,
        inputCostPerMillionUsd: 0.05,
        outputCostPerMillionUsd: 0.15,
        supportedLanguages: ['en', 'ar'],
        evalStatus: 'approved',
      },
    ],
  ]);

  private static readonly taskDefaultModels: Record<TaskClass, string> = {
    calculation: 'deterministic', // handled without LLM!
    intent_classification: 'gemini-3.8-flash',
    conversational: 'gemini-3.8-flash',
    general_qa: 'gemini-3.8-flash',
    structured_analysis: 'gemini-3.8-flash',
    complex_analysis: 'gemini-3.8-flash',
    vision_extraction: 'gemini-3.8-flash',
    summarization: 'gemini-3.8-flash',
    embedding: 'text-embedding-004',
  };

  public static getModel(id: string): ModelDefinition | undefined {
    return this.models.get(id);
  }

  public static getAllModels(): ModelDefinition[] {
    return Array.from(this.models.values());
  }

  public static getDefaultModelForTask(task: TaskClass): string {
    return this.taskDefaultModels[task];
  }

  public static registerModel(model: ModelDefinition): void {
    this.models.set(model.id, model);
  }
}
