/**
 * AI Gateway Domain (ADR-005, §10.9, §20.5)
 *
 * Rules:
 * - Capability slots: text, vision, embedding.
 * - At least two independent text provider adapters (e.g., OpenAI, Gemini).
 * - BYOK-readiness: Encrypted secret custody, write-only, client never sees secrets.
 * - Deterministic-first task/model routing (ADR-023).
 * - No domain modules import provider SDKs.
 */

import crypto from 'crypto';

export type CapabilitySlot = 'text' | 'vision' | 'embedding';

export type TaskClass =
  | 'deterministic_calculation' // Routed to pure code, 0 tokens
  | 'intent_classification'
  | 'safety_prescreen'
  | 'lookup_phrasing'
  | 'general_qa'
  | 'structured_analysis'
  | 'deep_multistep_analysis'
  | 'image_extraction'
  | 'summarization';

export interface ModelDescriptor {
  modelId: string;
  provider: 'openai' | 'gemini' | 'mock';
  capabilities: CapabilitySlot[];
  contextWindowTokens: number;
  costPer1kInputTokensUsd: number;
  costPer1kOutputTokensUsd: number;
  evalStatus: 'approved' | 'provisional' | 'rejected';
}

export interface PromptPayload {
  systemPrompt: string;
  userPrompt: string;
  temperature?: number;
  responseSchema?: Record<string, unknown>;
}

export interface ProviderResponse {
  content: string;
  promptTokens: number;
  completionTokens: number;
  provider: string;
  model: string;
  latencyMs: number;
}

export interface ProviderAdapter {
  providerName: string;
  supportedModels: ModelDescriptor[];
  generateText(modelId: string, prompt: PromptPayload, apiKey?: string): Promise<ProviderResponse>;
}

export class MockOpenAIAdapter implements ProviderAdapter {
  providerName = 'openai';
  supportedModels: ModelDescriptor[] = [
    {
      modelId: 'gpt-4o-mini',
      provider: 'openai',
      capabilities: ['text', 'vision'],
      contextWindowTokens: 128000,
      costPer1kInputTokensUsd: 0.00015,
      costPer1kOutputTokensUsd: 0.0006,
      evalStatus: 'approved',
    },
    {
      modelId: 'gpt-4o',
      provider: 'openai',
      capabilities: ['text', 'vision'],
      contextWindowTokens: 128000,
      costPer1kInputTokensUsd: 0.005,
      costPer1kOutputTokensUsd: 0.015,
      evalStatus: 'approved',
    },
  ];

  async generateText(modelId: string, prompt: PromptPayload): Promise<ProviderResponse> {
    const start = Date.now();
    return {
      content: JSON.stringify({
        summary: 'OpenAI response generated',
        evidence: ['retrieved', 'calculated'],
      }),
      promptTokens: 250,
      completionTokens: 85,
      provider: this.providerName,
      model: modelId,
      latencyMs: Date.now() - start + 45,
    };
  }
}

export class MockGeminiAdapter implements ProviderAdapter {
  providerName = 'gemini';
  supportedModels: ModelDescriptor[] = [
    {
      modelId: 'gemini-1.5-flash',
      provider: 'gemini',
      capabilities: ['text', 'vision'],
      contextWindowTokens: 1000000,
      costPer1kInputTokensUsd: 0.000075,
      costPer1kOutputTokensUsd: 0.0003,
      evalStatus: 'approved',
    },
    {
      modelId: 'gemini-1.5-pro',
      provider: 'gemini',
      capabilities: ['text', 'vision'],
      contextWindowTokens: 2000000,
      costPer1kInputTokensUsd: 0.0035,
      costPer1kOutputTokensUsd: 0.0105,
      evalStatus: 'approved',
    },
  ];

  async generateText(modelId: string, prompt: PromptPayload): Promise<ProviderResponse> {
    const start = Date.now();
    return {
      content: JSON.stringify({
        summary: 'Gemini response generated',
        evidence: ['retrieved', 'calculated'],
      }),
      promptTokens: 240,
      completionTokens: 80,
      provider: this.providerName,
      model: modelId,
      latencyMs: Date.now() - start + 40,
    };
  }
}

export class AiGateway {
  private static adapters: Map<string, ProviderAdapter> = new Map();

  static {
    this.registerAdapter(new MockOpenAIAdapter());
    this.registerAdapter(new MockGeminiAdapter());
  }

  static registerAdapter(adapter: ProviderAdapter): void {
    this.adapters.set(adapter.providerName, adapter);
  }

  /**
   * Task/Model Router (ADR-023)
   * Principle: Deterministic first, smallest capable model second.
   */
  static routeTask(taskClass: TaskClass): {
    requiresModel: boolean;
    provider?: string;
    modelId?: string;
    reason: string;
  } {
    if (taskClass === 'deterministic_calculation') {
      return {
        requiresModel: false,
        reason: 'Mathematical calculation routed to deterministic calculation engine (0 tokens).',
      };
    }

    if (taskClass === 'intent_classification' || taskClass === 'safety_prescreen' || taskClass === 'lookup_phrasing') {
      return {
        requiresModel: true,
        provider: 'gemini',
        modelId: 'gemini-1.5-flash',
        reason: 'Lightweight fast model selected for classification/lookup.',
      };
    }

    if (taskClass === 'deep_multistep_analysis') {
      return {
        requiresModel: true,
        provider: 'openai',
        modelId: 'gpt-4o',
        reason: 'High-capability reasoning model selected for deep multi-step analysis.',
      };
    }

    // Default structured analysis
    return {
      requiresModel: true,
      provider: 'openai',
      modelId: 'gpt-4o-mini',
      reason: 'Balanced cost-to-capability model selected for structured analysis.',
    };
  }

  /**
   * Secret Custody for BYOK (ADR-018, §20.5)
   * Envelope encryption using AES-256-GCM.
   */
  static encryptByokKey(rawKey: string, masterKeyHex: string): {
    encryptedKey: string;
    iv: string;
    authTag: string;
    maskedKey: string;
  } {
    const iv = crypto.randomBytes(12);
    const cipher = crypto.createCipheriv('aes-256-gcm', Buffer.from(masterKeyHex, 'hex'), iv);
    let encrypted = cipher.update(rawKey, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    const authTag = cipher.getAuthTag().toString('hex');

    const maskedKey =
      rawKey.length > 8
        ? `${rawKey.substring(0, 3)}...${rawKey.substring(rawKey.length - 4)}`
        : '****';

    return {
      encryptedKey: encrypted,
      iv: iv.toString('hex'),
      authTag,
      maskedKey,
    };
  }

  static decryptByokKey(
    encryptedKey: string,
    ivHex: string,
    authTagHex: string,
    masterKeyHex: string
  ): string {
    const decipher = crypto.createDecipheriv(
      'aes-256-gcm',
      Buffer.from(masterKeyHex, 'hex'),
      Buffer.from(ivHex, 'hex')
    );
    decipher.setAuthTag(Buffer.from(authTagHex, 'hex'));
    let decrypted = decipher.update(encryptedKey, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    return decrypted;
  }

  /**
   * Dispatch prompt execution with provider fallback support.
   */
  static async execute(
    providerName: string,
    modelId: string,
    prompt: PromptPayload,
    apiKey?: string
  ): Promise<ProviderResponse> {
    const adapter = this.adapters.get(providerName);
    if (!adapter) {
      throw new Error(`AI Provider adapter '${providerName}' not found`);
    }

    try {
      return await adapter.generateText(modelId, prompt, apiKey);
    } catch (err) {
      // Fallback chain: fallback from openai -> gemini or vice-versa
      const fallbackProvider = providerName === 'openai' ? 'gemini' : 'openai';
      const fallbackModel = fallbackProvider === 'gemini' ? 'gemini-1.5-flash' : 'gpt-4o-mini';
      const fallbackAdapter = this.adapters.get(fallbackProvider);
      if (fallbackAdapter) {
        return await fallbackAdapter.generateText(fallbackModel, prompt);
      }
      throw err;
    }
  }
}
