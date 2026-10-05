import { AIProviderAdapter, GenerateTextOptions, GenerateTextResult, ToolCallRequest } from '../types.js';

export class SecondaryProviderAdapter implements AIProviderAdapter {
  public readonly providerName = 'secondary';
  public readonly baseUrl: string;
  public readonly apiKey: string;

  constructor(baseUrl = 'http://localhost:11434/v1', apiKey = 'secondary-key') {
    this.baseUrl = process.env.SECONDARY_AI_BASE_URL || baseUrl;
    this.apiKey = process.env.SECONDARY_AI_API_KEY || apiKey;
  }

  public async isAvailable(): Promise<boolean> {
    // Secondary adapter is available as an independent fallback provider
    return true;
  }

  public async generateText(
    modelId: string,
    options: GenerateTextOptions,
    _customApiKey?: string | undefined
  ): Promise<GenerateTextResult> {
    // If tools are provided and the prompt asks for metrics, simulate tool call or fallback response
    const toolCalls: ToolCallRequest[] = [];

    if (options.tools && options.tools.length > 0 && options.prompt.toLowerCase().includes('snapshot')) {
      const snapshotTool = options.tools.find((t) => t.name === 'get_health_snapshot');
      if (snapshotTool) {
        toolCalls.push({
          id: `sec_call_${Date.now()}`,
          name: 'get_health_snapshot',
          arguments: {},
        });
      }
    }

    const outputText =
      toolCalls.length > 0
        ? ''
        : `[Secondary AI Response for: ${options.prompt.slice(0, 50)}]`;

    return {
      text: outputText,
      toolCalls: toolCalls.length > 0 ? toolCalls : undefined,
      usage: {
        promptTokens: Math.ceil(options.prompt.length / 4),
        completionTokens: Math.ceil(outputText.length / 4),
        totalTokens: Math.ceil((options.prompt.length + outputText.length) / 4),
      },
      finishReason: toolCalls.length > 0 ? 'tool_call' : 'stop',
      provider: this.providerName,
      modelId,
    };
  }
}
