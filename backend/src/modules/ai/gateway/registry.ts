import { ModelDefinition, TaskClass } from './types.js';

export class ModelRegistry {
  private static readonly models: Map<string, ModelDefinition> = new Map([
    [
      'gemini-flash-latest',
      {
        id: 'gemini-flash-latest',
        provider: 'google',
        displayName: 'Google Gemini Flash Latest',
        capabilities: ['text', 'vision', 'structured_output', 'tool_calling'],
        contextWindow: 1048576,
        maxOutputTokens: 8192,
        inputCostPerMillionUsd: 0.075,
        outputCostPerMillionUsd: 0.3,
        supportedLanguages: ['en', 'ar'],
        evalStatus: 'approved',
      },
    ],
    [
      'gemini-1.5-flash',
      {
        id: 'gemini-1.5-flash',
        provider: 'google',
        displayName: 'Google Gemini 1.5 Flash',
        capabilities: ['text', 'vision', 'structured_output', 'tool_calling'],
        contextWindow: 1048576,
        maxOutputTokens: 8192,
        inputCostPerMillionUsd: 0.075,
        outputCostPerMillionUsd: 0.3,
        supportedLanguages: ['en', 'ar'],
        evalStatus: 'approved',
      },
    ],
    [
      'gemini-2.0-flash',
      {
        id: 'gemini-2.0-flash',
        provider: 'google',
        displayName: 'Google Gemini 2.0 Flash',
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
      'gemini-3.8-flash',
      {
        id: 'gemini-3.8-flash',
        provider: 'google',
        displayName: 'Google Gemini 3.8 Flash (Preview)',
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
      'gpt-4o-mini',
      {
        id: 'gpt-4o-mini',
        provider: 'openai',
        displayName: 'OpenAI GPT-4o Mini',
        capabilities: ['text', 'vision', 'structured_output', 'tool_calling'],
        contextWindow: 128000,
        maxOutputTokens: 4096,
        inputCostPerMillionUsd: 0.15,
        outputCostPerMillionUsd: 0.6,
        supportedLanguages: ['en', 'ar'],
        evalStatus: 'approved',
      },
    ],
    [
      'gpt-4o',
      {
        id: 'gpt-4o',
        provider: 'openai',
        displayName: 'OpenAI GPT-4o',
        capabilities: ['text', 'vision', 'structured_output', 'tool_calling'],
        contextWindow: 128000,
        maxOutputTokens: 4096,
        inputCostPerMillionUsd: 2.5,
        outputCostPerMillionUsd: 10.0,
        supportedLanguages: ['en', 'ar'],
        evalStatus: 'approved',
      },
    ],
    [
      'claude-3-5-sonnet',
      {
        id: 'claude-3-5-sonnet',
        provider: 'anthropic',
        displayName: 'Claude 3.5 Sonnet',
        capabilities: ['text', 'vision', 'structured_output', 'tool_calling'],
        contextWindow: 200000,
        maxOutputTokens: 8192,
        inputCostPerMillionUsd: 3.0,
        outputCostPerMillionUsd: 15.0,
        supportedLanguages: ['en', 'ar'],
        evalStatus: 'approved',
      },
    ],
    [
      'gemini-3.5-flash-lite',
      {
        id: 'gemini-3.5-flash-lite',
        provider: 'google',
        displayName: 'Google Gemini 3.5 Flash Lite',
        capabilities: ['text', 'vision', 'structured_output', 'tool_calling'],
        contextWindow: 1048576,
        maxOutputTokens: 8192,
        inputCostPerMillionUsd: 0.075,
        outputCostPerMillionUsd: 0.3,
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
    intent_classification: 'gemini-3.5-flash-lite',
    conversational: 'gemini-3.5-flash-lite',
    general_qa: 'gemini-3.5-flash-lite',
    structured_analysis: 'gemini-3.5-flash-lite',
    complex_analysis: 'gemini-3.5-flash-lite',
    vision_extraction: 'gemini-3.5-flash-lite',
    summarization: 'gemini-3.5-flash-lite',
    embedding: 'text-embedding-004',
  };

  public static getModel(id: string): ModelDefinition | undefined {
    return this.models.get(id);
  }

  public static getAllModels(): ModelDefinition[] {
    return Array.from(this.models.values());
  }

  public static getDefaultModelForTask(task: TaskClass): string {
    return this.taskDefaultModels[task] || 'gemini-1.5-flash';
  }

  public static getDefaultModelForProvider(provider: string, task: TaskClass): string {
    if (task === 'calculation') return 'deterministic';
    const norm = provider.toLowerCase();
    if (norm === 'openai') return 'gpt-4o-mini';
    if (norm === 'anthropic') return 'claude-3-5-sonnet';
    if (norm === 'secondary') return 'forma-secondary-text-v1';
    return this.getDefaultModelForTask(task);
  }

  public static registerModel(model: ModelDefinition): void {
    this.models.set(model.id, model);
  }
}
