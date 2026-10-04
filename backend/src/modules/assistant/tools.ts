/**
 * AI Tool Registry & Capability Boundaries (ADR-007, §12)
 *
 * Rules:
 * - Server-mediated capability catalog: strict input/output schemas.
 * - Identity Injection: authenticated userId is bound server-side.
 *   Tool schemas MUST NOT contain a userId parameter.
 * - No raw query access.
 * - Least privilege per turn.
 * - Tool outputs wrapped as untrusted data.
 */

import { SnapshotEngine, HealthSnapshot } from '../analytics/snapshot.js';
import { CalculationEngine } from '../calculations/engine.js';
import { UserProfile } from '../profile/model.js';
import { Observation } from '../measurements/model.js';
import { Goal } from '../goals/model.js';

export interface ToolContext {
  userId: string;
  profile: UserProfile;
  observations: Observation[];
  goals: Goal[];
  cachedSnapshot?: HealthSnapshot;
}

export interface ToolDefinition<TParams = any, TResult = any> {
  name: string;
  description: string;
  parametersSchema: Record<string, unknown>;
  permissionClass: 'read_only' | 'safe_write' | 'sensitive_write';
  execute(params: TParams, context: ToolContext): Promise<TResult>;
}

export class ToolRegistry {
  private static tools: Map<string, ToolDefinition> = new Map();

  static {
    // 1. Tool: get_health_snapshot
    this.register({
      name: 'get_health_snapshot',
      description: 'Retrieve the user compact Health Snapshot (current state, body status, goals, energy).',
      parametersSchema: {
        type: 'object',
        properties: {
          sections: {
            type: 'array',
            items: { type: 'string', enum: ['identityLite', 'bodyStatus', 'primaryGoal', 'energy', 'anomalies'] },
            description: 'Optional list of specific sections to retrieve',
          },
        },
      },
      permissionClass: 'read_only',
      async execute(params: { sections?: string[] }, context: ToolContext) {
        const snapshot =
          context.cachedSnapshot ??
          SnapshotEngine.generateSnapshot({
            profile: context.profile,
            observations: context.observations,
            goals: context.goals,
          });

        if (params.sections && params.sections.length > 0) {
          const filteredSections: Record<string, unknown> = {};
          for (const s of params.sections) {
            if ((snapshot.sections as any)[s]) {
              filteredSections[s] = (snapshot.sections as any)[s];
            }
          }
          return {
            userId: context.userId,
            asOf: snapshot.generatedAt,
            sections: filteredSections,
          };
        }

        return snapshot;
      },
    });

    // 2. Tool: calculate_tdee_and_targets
    this.register({
      name: 'calculate_tdee_and_targets',
      description: 'Run deterministic calculation engine for TDEE, calorie target, and macros with safety guardrails.',
      parametersSchema: {
        type: 'object',
        properties: {
          weightKg: { type: 'number', description: 'Body weight in kg' },
          goalType: {
            type: 'string',
            enum: ['fat_loss', 'weight_loss', 'muscle_gain', 'maintenance', 'recomposition'],
          },
          rateKgPerWeek: { type: 'number', description: 'Desired rate of weight change per week' },
        },
        required: ['goalType'],
      },
      permissionClass: 'read_only',
      async execute(
        params: { weightKg?: number; goalType: any; rateKgPerWeek?: number },
        context: ToolContext
      ) {
        const weight = params.weightKg ?? 75;
        const bmr = CalculationEngine.calculateBmr({
          weightKg: weight,
          heightCm: context.profile.heightCm,
          sex: context.profile.sexForCalculation,
          ageYears: 30,
        });

        const tdee = CalculationEngine.calculateTdee({
          bmrKcal: bmr.value.bmrKcal,
          activityLevel: context.profile.activityLevel,
        });

        const target = CalculationEngine.calculateCalorieTarget({
          tdeeKcal: tdee.value.tdeeKcal,
          goalType: params.goalType,
          rateKgPerWeek: params.rateKgPerWeek,
          sex: context.profile.sexForCalculation,
        });

        const macros = CalculationEngine.calculateMacros({
          targetCalories: target.value.targetCalories,
          weightKg: weight,
          goalType: params.goalType,
        });

        return {
          bmr: bmr.value,
          tdee: tdee.value,
          targetCalories: target.value,
          macros: macros.value,
          guardrails: {
            clamped: target.value.guardrailClamped,
            safetyFlags: target.safetyFlags,
          },
        };
      },
    });
  }

  static register(tool: ToolDefinition): void {
    this.tools.set(tool.name, tool);
  }

  static get(name: string): ToolDefinition {
    const tool = this.tools.get(name);
    if (!tool) {
      throw new Error(`Tool '${name}' is not registered`);
    }
    return tool;
  }

  static getCatalog(): Array<Omit<ToolDefinition, 'execute'>> {
    return Array.from(this.tools.values()).map(({ execute, ...meta }) => meta);
  }

  static async invokeTool(name: string, params: any, context: ToolContext): Promise<any> {
    const tool = this.get(name);
    // Execute tool with injected context
    return await tool.execute(params, context);
  }
}
