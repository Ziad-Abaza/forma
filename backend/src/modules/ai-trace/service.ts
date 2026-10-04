/**
 * AI Traceability & Usage Ledger (ADR-022, §12.8)
 *
 * Rules:
 * - Content-minimized AI Trace Record: versions, routing, context manifest,
 *   tools invoked, evidence composition, safety classification, budget consumption.
 * - Zero prompts, zero completions, zero raw health values stored in trace by default.
 * - Usage ledger projected for cost and token monitoring.
 */

import { ContextManifest } from '../assistant/context.js';

export interface AiTraceRecord {
  id: string;
  userId: string;
  operationType: 'assistant_turn' | 'extraction' | 'digest' | 'action_proposal';
  taskClass: string;
  provider: string;
  model: string;
  routingReason: string;
  versions: {
    promptVersion: string;
    policyVersion: string;
    toolSchemaVersion: string;
    formulaVersion: string;
  };
  contextManifest: ContextManifest;
  toolsInvoked: Array<{ toolName: string; durationMs: number; success: boolean }>;
  evidenceTypes: Array<'retrieved' | 'calculated' | 'estimated' | 'inferred' | 'unknown'>;
  safetyCategory: 'wellness' | 'nutrition' | 'educational' | 'concern_redirect';
  guardrailsTriggered: string[];
  budgetConsumed: {
    inputTokens: number;
    outputTokens: number;
    latencyMs: number;
    costUsd: number;
  };
  outcome: 'success' | 'degraded' | 'refused' | 'error';
  timestamp: string;
}

export class AiTraceService {
  private static traces: AiTraceRecord[] = [];

  static recordTrace(trace: Omit<AiTraceRecord, 'id' | 'timestamp'>): AiTraceRecord {
    const fullTrace: AiTraceRecord = {
      ...trace,
      id: `trace_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      timestamp: new Date().toISOString(),
    };
    this.traces.push(fullTrace);
    return fullTrace;
  }

  static getTracesForUser(userId: string): AiTraceRecord[] {
    return this.traces.filter((t) => t.userId === userId);
  }
}
