import { AIProviderAdapter, GenerateTextOptions, GenerateTextResult, TaskClass } from './types.js';
import { ModelRegistry } from './registry.js';
import { createBuiltinAdapters } from './adapters/index.js';
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
    for (const adapter of createBuiltinAdapters()) {
      this.registerAdapter(adapter);
    }
  }

  public registerAdapter(adapter: AIProviderAdapter): void {
    this.adapters.set(adapter.providerName.toLowerCase(), adapter);
  }

  public getAdapter(provider: string): AIProviderAdapter | undefined {
    return this.adapters.get(provider.toLowerCase());
  }

  /**
   * Providers with an actually-registered adapter. Anything not listed here
   * cannot serve a request — config endpoints must report this truthfully.
   */
  public getRegisteredProviders(): string[] {
    return Array.from(this.adapters.keys());
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

    // Determine target provider: respect user's active configured BYOK provider.
    // A missing provider is an honest error, never a silently assumed 'google'.
    let activeProvider = 'google';
    if (userId && this.byokService) {
      const configured = await this.byokService.getActiveProvider(userId);
      if (!configured) {
        throw new Error(
          'No AI provider credential configured. Please add a provider API key in Settings -> AI Provider.'
        );
      }
      activeProvider = configured;
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

    if (userId) {
      if (!targetApiKey) {
        throw new Error(
          `No AI credential configured for provider '${targetModel.provider}'. Please configure your API key in Settings -> AI Provider.`
        );
      }
      if (!adapter) {
        throw new Error(`AI adapter for provider '${targetModel.provider}' is not registered`);
      }

      // User-owned AI flow: NO SILENT FALLBACK (Blueprint §10, ADR-018)
      // When a user configures their own provider, any error from Google/OpenAI must be reported directly.
      finalResult = await adapter.generateText(targetModel.id, options, targetApiKey);
    } else {
      // System/automated test flow without authenticated user context
      if (adapter && (await adapter.isAvailable() || Boolean(targetApiKey))) {
        try {
          finalResult = await adapter.generateText(targetModel.id, options, targetApiKey);
        } catch (err: any) {
          // Fallback to secondary provider in non-user system test mode
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
