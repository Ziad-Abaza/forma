// AI Gateway Core Types & Interfaces (Blueprint §10.9, §12, §24)

export type TaskClass =
  | 'calculation'
  | 'intent_classification'
  | 'conversational'
  | 'general_qa'
  | 'structured_analysis'
  | 'complex_analysis'
  | 'vision_extraction'
  | 'summarization'
  | 'embedding';

export type AICapability =
  | 'text'
  | 'vision'
  | 'structured_output'
  | 'tool_calling'
  | 'embedding';

export interface ModelDefinition {
  id: string;
  provider: string;
  displayName: string;
  capabilities: AICapability[];
  contextWindow: number;
  maxOutputTokens: number;
  inputCostPerMillionUsd: number;
  outputCostPerMillionUsd: number;
  supportedLanguages: string[];
  evalStatus: 'approved' | 'candidate' | 'deprecated';
}

export interface ToolCallRequest {
  id: string;
  name: string;
  arguments: Record<string, unknown>;
}

export interface ToolCallResponse {
  callId: string;
  name: string;
  result: Record<string, unknown>;
}

export interface GenerateTextOptions {
  prompt: string;
  systemInstruction?: string | undefined;
  temperature?: number | undefined;
  maxTokens?: number | undefined;
  responseJsonSchema?: Record<string, unknown> | undefined;
  tools?: Array<{
    name: string;
    description: string;
    parameters: Record<string, unknown>;
  }> | undefined;
  toolResponses?: ToolCallResponse[] | undefined;
  inlineData?: Array<{ mimeType: string; data: string }> | undefined;
}

/**
 * Token usage reported BY THE PROVIDER. Fields are null when the provider
 * omits them — adapters must never substitute estimates for real usage.
 */
export interface TokenUsage {
  promptTokens: number | null;
  completionTokens: number | null;
  totalTokens: number | null;
}

export interface GenerateTextResult {
  text: string;
  toolCalls?: ToolCallRequest[] | undefined;
  usage: TokenUsage;
  finishReason: 'stop' | 'length' | 'tool_call' | 'error';
  provider: string;
  modelId: string;
}

export interface AIProviderAdapter {
  readonly providerName: string;
  isAvailable(): Promise<boolean>;
  generateText(
    modelId: string,
    options: GenerateTextOptions,
    customApiKey?: string | undefined
  ): Promise<GenerateTextResult>;
}
