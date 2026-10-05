// AI Data Budget Governance & Enforcement (Blueprint §11.9, ADR-020)

export interface BudgetProfile {
  name: 'minimal' | 'standard' | 'deep_analysis';
  maxToolCallsPerTurn: number;
  maxSequentialRounds: number;
  maxContextTokens: number;
  maxResponseTokens: number;
  maxTimeoutMs: number;
}

export const BUDGET_PROFILES: Record<string, BudgetProfile> = {
  minimal: {
    name: 'minimal',
    maxToolCallsPerTurn: 2,
    maxSequentialRounds: 1,
    maxContextTokens: 2048,
    maxResponseTokens: 512,
    maxTimeoutMs: 8000,
  },
  standard: {
    name: 'standard',
    maxToolCallsPerTurn: 5,
    maxSequentialRounds: 3,
    maxContextTokens: 8192,
    maxResponseTokens: 1024,
    maxTimeoutMs: 15000,
  },
  deep_analysis: {
    name: 'deep_analysis',
    maxToolCallsPerTurn: 10,
    maxSequentialRounds: 5,
    maxContextTokens: 32768,
    maxResponseTokens: 2048,
    maxTimeoutMs: 30000,
  },
};

export interface BudgetConsumption {
  toolCalls: number;
  sequentialRounds: number;
  tokensConsumed: number;
  elapsedMs: number;
  isExhausted: boolean;
  exhaustionDimension?: string | undefined;
}

export class AIBudgetEnforcer {
  private readonly startTime = Date.now();
  private toolCalls = 0;
  private sequentialRounds = 0;
  private tokensConsumed = 0;

  constructor(public readonly profile: BudgetProfile = BUDGET_PROFILES.standard!) {}

  public recordRound(): void {
    this.sequentialRounds += 1;
    if (this.sequentialRounds > this.profile.maxSequentialRounds) {
      throw new Error(
        `AI Data Budget Exhausted: sequential rounds (${this.sequentialRounds}) exceeded limit (${this.profile.maxSequentialRounds})`
      );
    }
  }

  public recordToolCall(): void {
    this.toolCalls += 1;
    if (this.toolCalls > this.profile.maxToolCallsPerTurn) {
      throw new Error(
        `AI Data Budget Exhausted: tool calls (${this.toolCalls}) exceeded limit (${this.profile.maxToolCallsPerTurn})`
      );
    }
  }

  public recordTokens(tokens: number): void {
    this.tokensConsumed += tokens;
    if (this.tokensConsumed > this.profile.maxContextTokens + this.profile.maxResponseTokens) {
      throw new Error(
        `AI Data Budget Exhausted: tokens (${this.tokensConsumed}) exceeded ceiling (${
          this.profile.maxContextTokens + this.profile.maxResponseTokens
        })`
      );
    }
  }

  public checkTimeout(): void {
    const elapsed = Date.now() - this.startTime;
    if (elapsed > this.profile.maxTimeoutMs) {
      throw new Error(
        `AI Data Budget Exhausted: execution time (${elapsed}ms) exceeded timeout (${this.profile.maxTimeoutMs}ms)`
      );
    }
  }

  public getConsumption(): BudgetConsumption {
    const elapsed = Date.now() - this.startTime;
    return {
      toolCalls: this.toolCalls,
      sequentialRounds: this.sequentialRounds,
      tokensConsumed: this.tokensConsumed,
      elapsedMs: elapsed,
      isExhausted:
        this.toolCalls > this.profile.maxToolCallsPerTurn ||
        this.sequentialRounds > this.profile.maxSequentialRounds ||
        elapsed > this.profile.maxTimeoutMs,
    };
  }
}
