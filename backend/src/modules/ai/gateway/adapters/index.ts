import type { AIProviderAdapter } from '../types.js';
import { GeminiAdapter } from './gemini.js';
import { OpenAIAdapter } from './openai.js';
import { SecondaryProviderAdapter } from './secondary.js';

/**
 * The set of provider adapters the gateway registers by default.
 * This is the single source of truth for "which providers can actually serve
 * a request" — BYOK allowlists and config endpoints must derive from it.
 */
export function createBuiltinAdapters(): AIProviderAdapter[] {
  return [new GeminiAdapter(), new OpenAIAdapter(), new SecondaryProviderAdapter()];
}

export const BUILTIN_PROVIDER_NAMES: readonly string[] = createBuiltinAdapters().map(
  (adapter) => adapter.providerName
);
