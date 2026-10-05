import { AIProviderAdapter, GenerateTextOptions, GenerateTextResult, ToolCallRequest } from '../types.js';
import { config } from '../../../../config/index.js';

export class SecondaryProviderAdapter implements AIProviderAdapter {
  public readonly providerName = 'secondary';
  public readonly baseUrl: string | undefined;
  public readonly apiKey: string;
  private readonly customFetch?: (typeof fetch) | undefined;

  /**
   * No implicit localhost default: the secondary provider is only "available"
   * when explicitly configured via SECONDARY_AI_BASE_URL or constructor args.
   */
  constructor(
    baseUrl?: string | undefined,
    apiKey?: string | undefined,
    customFetch?: (typeof fetch) | undefined
  ) {
    this.baseUrl = baseUrl ?? config.SECONDARY_AI_BASE_URL;
    this.apiKey = apiKey ?? config.SECONDARY_AI_API_KEY ?? '';
    this.customFetch = customFetch;
  }

  public async isAvailable(): Promise<boolean> {
    return Boolean(this.baseUrl && this.baseUrl.trim().length > 0);
  }

  public async generateText(
    modelId: string,
    options: GenerateTextOptions,
    customApiKey?: string | undefined
  ): Promise<GenerateTextResult> {
    if (!this.baseUrl) {
      throw new Error('Secondary AI provider is not configured (set SECONDARY_AI_BASE_URL)');
    }
    const key = customApiKey || this.apiKey;
    const cleanBase = this.baseUrl.endsWith('/') ? this.baseUrl.slice(0, -1) : this.baseUrl;
    const endpoint = `${cleanBase}/chat/completions`;

    const messages: Array<{ role: string; content: string }> = [];
    if (options.systemInstruction) {
      messages.push({ role: 'system', content: options.systemInstruction });
    }
    messages.push({ role: 'user', content: options.prompt });

    const body: Record<string, unknown> = {
      model: modelId,
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

    const fetchFn = this.customFetch || fetch;

    try {
      const response = await fetchFn(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(key ? { Authorization: `Bearer ${key}` } : {}),
        },
        body: JSON.stringify(body),
      });

      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`Secondary AI provider error (${response.status}): ${errorText}`);
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
        modelId,
      };
    } catch (err: any) {
      throw new Error(`Secondary AI provider connection failed: ${err.message}`);
    }
  }
}
