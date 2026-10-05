import { AIProviderAdapter, GenerateTextOptions, GenerateTextResult, ToolCallRequest } from '../types.js';

export class GeminiAdapter implements AIProviderAdapter {
  public readonly providerName = 'google';
  private readonly defaultApiKey: string;
  private readonly baseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  constructor(apiKey?: string) {
    this.defaultApiKey = apiKey || process.env.GEMINI_API_KEY || '';
  }

  public async isAvailable(): Promise<boolean> {
    return Boolean(this.defaultApiKey && this.defaultApiKey.trim().length > 0);
  }

  public async generateText(
    modelId: string,
    options: GenerateTextOptions,
    customApiKey?: string | undefined
  ): Promise<GenerateTextResult> {
    const apiKey = customApiKey || this.defaultApiKey;
    if (!apiKey) {
      throw new Error('GEMINI_API_KEY is not configured and no custom key provided');
    }

    const resolvedModel = (!modelId || modelId === 'gemini-1.5-flash')
      ? (process.env.GEMINI_MODEL || 'gemini-3.5-flash-lite')
      : modelId;

    const isBearer = apiKey.startsWith('ya29.');
    const endpoint = `${this.baseUrl}/models/${resolvedModel}:generateContent`;

    const contents: Array<Record<string, unknown>> = [];

    // Add user turn
    const parts: Array<Record<string, unknown>> = [];

    // If inline image/multimodal data exists, attach inlineData parts
    if (options.inlineData && options.inlineData.length > 0) {
      for (const item of options.inlineData) {
        parts.push({
          inlineData: {
            mimeType: item.mimeType,
            data: item.data
          }
        });
      }
    }

    parts.push({ text: options.prompt });

    // If tool responses exist, supply them
    if (options.toolResponses && options.toolResponses.length > 0) {
      for (const tr of options.toolResponses) {
        parts.push({
          functionResponse: {
            name: tr.name,
            response: tr.result,
          },
        });
      }
    }

    contents.push({
      role: 'user',
      parts,
    });

    const requestBody: Record<string, unknown> = {
      contents,
    };

    if (options.systemInstruction) {
      requestBody.systemInstruction = {
        parts: [{ text: options.systemInstruction }],
      };
    }

    const generationConfig: Record<string, unknown> = {};
    if (options.temperature !== undefined) {
      generationConfig.temperature = options.temperature;
    }
    if (options.maxTokens !== undefined) {
      generationConfig.maxOutputTokens = options.maxTokens;
    }
    if (options.responseJsonSchema) {
      generationConfig.responseMimeType = 'application/json';
      generationConfig.responseSchema = options.responseJsonSchema;
    }

    if (Object.keys(generationConfig).length > 0) {
      requestBody.generationConfig = generationConfig;
    }

    if (options.tools && options.tools.length > 0) {
      requestBody.tools = [
        {
          functionDeclarations: options.tools.map((t) => ({
            name: t.name,
            description: t.description,
            parameters: t.parameters,
          })),
        },
      ];
    }

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      ...(isBearer
        ? { Authorization: `Bearer ${apiKey}` }
        : { 'x-goog-api-key': apiKey }),
    };

    const response = await fetch(endpoint, {
      method: 'POST',
      headers,
      body: JSON.stringify(requestBody),
    });

    if (!response.ok) {
      const errText = await response.text();
      // Mask any API key if present in error message
      const sanitized = errText.replace(/key=[^&\s]+/g, 'key=[REDACTED]');
      if (sanitized.includes('API_KEY_SERVICE_BLOCKED')) {
        throw new Error(
          `Gemini API Error [${response.status}] (API_KEY_SERVICE_BLOCKED): The API key is blocked for Generative Language API. Ensure 'Generative Language API' is enabled in Google Cloud Console with no restricting API scope, or create a key directly at https://aistudio.google.com/app/apikey. Details: ${sanitized}`
        );
      }
      throw new Error(`Gemini API Error [${response.status}]: ${sanitized}`);
    }

    const data = (await response.json()) as {
      candidates?: Array<{
        content?: {
          parts?: Array<{
            text?: string;
            functionCall?: {
              name: string;
              args: Record<string, unknown>;
            };
          }>;
        };
        finishReason?: string;
      }>;
      usageMetadata?: {
        promptTokenCount?: number;
        candidatesTokenCount?: number;
        totalTokenCount?: number;
      };
    };

    const candidate = data.candidates?.[0];
    let outputText = '';
    const toolCalls: ToolCallRequest[] = [];

    if (candidate?.content?.parts) {
      for (const part of candidate.content.parts) {
        if (part.text) {
          outputText += part.text;
        }
        if (part.functionCall) {
          toolCalls.push({
            id: `call_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
            name: part.functionCall.name,
            arguments: part.functionCall.args || {},
          });
        }
      }
    }

    const usage = {
      promptTokens: data.usageMetadata?.promptTokenCount || 0,
      completionTokens: data.usageMetadata?.candidatesTokenCount || 0,
      totalTokens: data.usageMetadata?.totalTokenCount || 0,
    };

    const finishReason =
      toolCalls.length > 0
        ? 'tool_call'
        : candidate?.finishReason === 'MAX_TOKENS'
        ? 'length'
        : 'stop';

    return {
      text: outputText,
      toolCalls: toolCalls.length > 0 ? toolCalls : undefined,
      usage,
      finishReason,
      provider: this.providerName,
      modelId,
    };
  }
}
