import { AIProviderAdapter, GenerateTextOptions, GenerateTextResult, TaskClass } from './types.js';
import { ModelRegistry } from './registry.js';
import { GeminiAdapter } from './adapters/gemini.js';
import { OpenAIAdapter } from './adapters/openai.js';
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
    // Register primary Google, OpenAI, and secondary text adapters
    this.registerAdapter(new GeminiAdapter());
    this.registerAdapter(new OpenAIAdapter());
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

    // Invariant: calculation tasks MUST NOT use an LLM
    if (taskClass === 'calculation') {
      throw new Error(`TaskClass '${taskClass}' is deterministic and must not be routed to an LLM`);
    }

    // Determine target provider: respect user's active configured BYOK provider
    let activeProvider = 'google';
    if (userId && this.byokService) {
      activeProvider = await this.byokService.getActiveProvider(userId);
    }

    let targetModelId = ModelRegistry.getDefaultModelForProvider(activeProvider, taskClass);
    if (targetModelId === 'deterministic') {
      throw new Error(`TaskClass '${taskClass}' is deterministic and must not be routed to an LLM`);
    }

    let targetModel = ModelRegistry.getModel(targetModelId);
    if (!targetModel) {
      targetModelId = ModelRegistry.getDefaultModelForTask(taskClass);
      targetModel = ModelRegistry.getModel(targetModelId);
    }
    if (!targetModel) {
      throw new Error(`Model '${targetModelId}' not found in registry`);
    }

    let targetApiKey: string | undefined;
    if (userId && this.byokService) {
      targetApiKey = await this.byokService.resolveUserKey(userId, targetModel.provider);
    }

    const adapter = this.adapters.get(targetModel.provider.toLowerCase());
    let fallbackUsed = false;
    let finalResult: GenerateTextResult;
    let selectedModel = targetModel.id;
    let selectedProvider = targetModel.provider;

    if (adapter && (await adapter.isAvailable() || Boolean(targetApiKey))) {
      try {
        finalResult = await adapter.generateText(targetModel.id, options, targetApiKey);
      } catch (err: any) {
        // Fallback to secondary or default provider
        const fallbackAdapter = this.adapters.get('secondary');
        if (fallbackAdapter && (await fallbackAdapter.isAvailable())) {
          fallbackUsed = true;
          selectedModel = 'forma-secondary-text-v1';
          selectedProvider = 'secondary';
          finalResult = await fallbackAdapter.generateText(selectedModel, options);
        } else {
          throw err;
        }
      }
    } else {
      // Primary adapter not available; try secondary fallback
      const fallbackAdapter = this.adapters.get('secondary');
      if (fallbackAdapter && (await fallbackAdapter.isAvailable())) {
        fallbackUsed = true;
        selectedModel = 'forma-secondary-text-v1';
        selectedProvider = 'secondary';
        finalResult = await fallbackAdapter.generateText(selectedModel, options);
      } else {
        throw new Error(
          `No configured AI provider adapter available for '${targetModel.provider}'. Please configure an API key in Settings.`
        );
      }
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
