import { AIProviderAdapter, GenerateTextOptions, GenerateTextResult, TaskClass } from './types.js';
import { ModelRegistry } from './registry.js';
import { GeminiAdapter } from './adapters/gemini.js';
import { SecondaryProviderAdapter } from './adapters/secondary.js';
import { BYOKService } from './byok.js';

export interface GatewayExecutionResult {
  result: GenerateTextResult;
  routing: {
    taskClass: TaskClass;
    selectedModel: string;
    selectedProvider: string;
    fallbackUsed: boolean;
    latencyMs: number;
  };
}

export class AIGateway {
  private readonly adapters: Map<string, AIProviderAdapter> = new Map();

  constructor(private readonly byokService?: BYOKService) {
    // Register primary and secondary text adapters
    this.registerAdapter(new GeminiAdapter());
    this.registerAdapter(new SecondaryProviderAdapter());
  }

  public registerAdapter(adapter: AIProviderAdapter): void {
    this.adapters.set(adapter.providerName.toLowerCase(), adapter);
  }

  public getAdapter(provider: string): AIProviderAdapter | undefined {
    return this.adapters.get(provider.toLowerCase());
  }

  public async execute(
    taskClass: TaskClass,
    options: GenerateTextOptions,
    userId?: string | undefined
  ): Promise<GatewayExecutionResult> {
    const startTime = Date.now();
    const primaryModelId = ModelRegistry.getDefaultModelForTask(taskClass);

    // Invariant: calculation tasks MUST NOT use an LLM
    if (primaryModelId === 'deterministic') {
      throw new Error(`TaskClass '${taskClass}' is deterministic and must not be routed to an LLM`);
    }

    const primaryModel = ModelRegistry.getModel(primaryModelId);
    if (!primaryModel) {
      throw new Error(`Model '${primaryModelId}' not found in registry`);
    }

    let primaryApiKey: string | undefined;
    if (userId && this.byokService) {
      primaryApiKey = await this.byokService.resolveUserKey(userId, primaryModel.provider);
    }

    const primaryAdapter = this.adapters.get(primaryModel.provider.toLowerCase());
    let fallbackUsed = false;
    let finalResult: GenerateTextResult;
    let selectedModel = primaryModel.id;
    let selectedProvider = primaryModel.provider;

    if (primaryAdapter && (await primaryAdapter.isAvailable())) {
      try {
        finalResult = await primaryAdapter.generateText(primaryModel.id, options, primaryApiKey);
      } catch (err) {
        // Fallback to secondary provider if primary fails
        const fallbackAdapter = this.adapters.get('secondary');
        if (!fallbackAdapter) throw err;

        fallbackUsed = true;
        selectedModel = 'forma-secondary-text-v1';
        selectedProvider = 'secondary';
        finalResult = await fallbackAdapter.generateText(selectedModel, options);
      }
    } else {
      // Primary not available, use secondary
      const fallbackAdapter = this.adapters.get('secondary');
      if (!fallbackAdapter) {
        throw new Error(`No available adapter found for task ${taskClass}`);
      }
      fallbackUsed = true;
      selectedModel = 'forma-secondary-text-v1';
      selectedProvider = 'secondary';
      finalResult = await fallbackAdapter.generateText(selectedModel, options);
    }

    const latencyMs = Date.now() - startTime;

    return {
      result: finalResult,
      routing: {
        taskClass,
        selectedModel,
        selectedProvider,
        fallbackUsed,
        latencyMs,
      },
    };
  }
}
