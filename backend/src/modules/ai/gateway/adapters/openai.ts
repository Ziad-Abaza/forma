import { AIProviderAdapter, GenerateTextOptions, GenerateTextResult, ToolCallRequest } from '../types.js';
import { config } from '../../../../config/index.js';

export class OpenAIAdapter implements AIProviderAdapter {
  public readonly providerName = 'openai';
  private readonly defaultApiKey: string;
  private readonly baseUrl: string;

  constructor(apiKey?: string, baseUrl?: string) {
    this.defaultApiKey = apiKey || config.OPENAI_API_KEY || '';
    // The public OpenAI API endpoint is a fixed upstream constant, not a secret.
    this.baseUrl = baseUrl || config.OPENAI_BASE_URL || 'https://api.openai.com/v1';
  }

  public async isAvailable(): Promise<boolean> {
    return Boolean(this.defaultApiKey && this.defaultApiKey.trim().length > 0);
  }

  public async generateText(
    modelId: string,
    options: GenerateTextOptions,
    customApiKey?: string | undefined
  ): Promise<GenerateTextResult> {
    const key = customApiKey || this.defaultApiKey;
    if (!key) {
      throw new Error('OPENAI_API_KEY is not configured and no custom key provided');
    }

    const cleanBase = this.baseUrl.endsWith('/') ? this.baseUrl.slice(0, -1) : this.baseUrl;
    const endpoint = `${cleanBase}/chat/completions`;

    // No silent model substitution — the caller selects the model via the
    // registry; an unrecognized id must fail at the provider, not be swapped.
    if (!modelId || modelId.trim().length === 0) {
      throw new Error('A concrete modelId is required for OpenAI generation');
    }
    const resolvedModel = modelId;

    const messages: Array<{ role: string; content: any }> = [];
    if (options.systemInstruction) {
      messages.push({ role: 'system', content: options.systemInstruction });
    }

    // Handle multimodal or text user prompt
    if (options.inlineData && options.inlineData.length > 0) {
      const contentParts: any[] = [{ type: 'text', text: options.prompt }];
      for (const item of options.inlineData) {
        contentParts.push({
          type: 'image_url',
          image_url: {
            url: `data:${item.mimeType};base64,${item.data}`
          }
        });
      }
      messages.push({ role: 'user', content: contentParts });
    } else {
      messages.push({ role: 'user', content: options.prompt });
    }

    const body: Record<string, unknown> = {
      model: resolvedModel,
      messages,
      temperature: options.temperature ?? 0.3,
      max_tokens: options.maxTokens ?? 1024,
    };

    if (options.tools && options.tools.length > 0) {
      body.tools = options.tools.map((t) => ({
        type: 'function',
        function: {
          name: t.name,
          description: t.description,
          parameters: t.parameters,
        },
      }));
    }

    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${key}`,
      },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const errorText = await response.text();
      let sanitized = errorText.replace(/Bearer\s+[A-Za-z0-9_\-]+/gi, 'Bearer [REDACTED]');
      sanitized = sanitized.replace(/sk-[A-Za-z0-9_\-]+/gi, 'sk-[REDACTED]');
      throw new Error(`OpenAI API error [${response.status}]: ${sanitized}`);
    }

    const data = (await response.json()) as any;
    const choice = data.choices?.[0];
    const message = choice?.message;

    const toolCalls: ToolCallRequest[] = [];
    if (message?.tool_calls && Array.isArray(message.tool_calls)) {
      for (const tc of message.tool_calls) {
        toolCalls.push({
          id: tc.id || `call_${Date.now()}`,
          name: tc.function?.name,
          arguments: tc.function?.arguments
            ? (typeof tc.function.arguments === 'string'
                ? JSON.parse(tc.function.arguments)
                : tc.function.arguments)
            : {},
        });
      }
    }

    return {
      text: message?.content || '',
      toolCalls: toolCalls.length > 0 ? toolCalls : undefined,
      usage: {
        promptTokens: data.usage?.prompt_tokens ?? Math.ceil(options.prompt.length / 4),
        completionTokens: data.usage?.completion_tokens ?? Math.ceil((message?.content || '').length / 4),
        totalTokens: data.usage?.total_tokens ?? 0,
      },
      finishReason: choice?.finish_reason || 'stop',
      provider: this.providerName,
      modelId: resolvedModel,
    };
  }
}
