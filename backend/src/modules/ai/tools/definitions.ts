import { z } from 'zod';
import { FormaTool } from './types.js';
import { CalculationEngine } from '../../calculations/engine.js';

// 1. Tool: get_health_snapshot
export const getHealthSnapshotTool: FormaTool = {
  name: 'get_health_snapshot',
  description: 'Retrieve the verified, lineage-watermarked health snapshot of the user.',
  permissionClass: 'read-only',
  inputSchema: z.object({
    section: z
      .enum([
        'all',
        'overview',
        'body_status',
        'energy',
        'trends',
        'anomalies',
        'goals',
        'recent_measurements',
        'data_quality',
      ])
      .default('all'),
  }),
  jsonSchema: {
    type: 'object',
    properties: {
      section: {
        type: 'string',
        enum: [
          'all',
          'overview',
          'body_status',
          'energy',
          'trends',
          'anomalies',
          'goals',
          'recent_measurements',
          'data_quality',
        ],
        description: 'The specific section of the snapshot to retrieve, or all.',
      },
    },
  },
  async execute(ctx, input) {
    if (!ctx.services.snapshotService) {
      throw new Error('SnapshotService is not available in tool context');
    }
    const snapshot = ctx.services.snapshotService.getOrRefreshSnapshot
      ? await ctx.services.snapshotService.getOrRefreshSnapshot(ctx.userId)
      : await ctx.services.snapshotService.getSnapshot(ctx.userId);
    if (!snapshot) {
      return { status: 'empty', message: 'No health snapshot available yet' };
    }

    if (input.section === 'all') {
      return {
        id: snapshot.id,
        asOf: snapshot.asOf,
        sourceWatermark: snapshot.sourceDataWatermark,
        sections: snapshot.sections,
      };
    }

    return {
      id: snapshot.id,
      asOf: snapshot.asOf,
      sourceWatermark: snapshot.sourceDataWatermark,
      sectionName: input.section,
      sectionData: snapshot.sections[input.section as keyof typeof snapshot.sections],
    };
  },
};

// 2. Tool: query_observations
export const queryObservationsTool: FormaTool = {
  name: 'query_observations',
  description: 'Retrieve bounded historical observations for a specific measurement type.',
  permissionClass: 'read-only',
  inputSchema: z.object({
    typeCode: z.string().min(1).max(64),
    limit: z.number().int().min(1).max(30).default(10),
  }),
  jsonSchema: {
    type: 'object',
    properties: {
      typeCode: {
        type: 'string',
        description: 'The measurement type code (e.g. weight, body_fat_percentage, resting_heart_rate).',
      },
      limit: {
        type: 'integer',
        minimum: 1,
        maximum: 30,
        description: 'Maximum number of recent observations to return (default 10, max 30).',
      },
    },
    required: ['typeCode'],
  },
  async execute(ctx, input) {
    if (!ctx.services.measurementsService) {
      throw new Error('MeasurementsService is not available in tool context');
    }
    const observations = await ctx.services.measurementsService.getObservations(ctx.userId, {
      typeCode: input.typeCode,
      limit: input.limit,
    });

    return {
      typeCode: input.typeCode,
      count: observations.length,
      observations: observations.map((o: any) => ({
        id: o.id,
        observedAt: o.observed_at || o.observedAt,
        canonicalValue: o.canonical_value || o.canonicalValue,
        canonicalUnit: o.canonical_unit || o.canonicalUnit,
        asEnteredValue: o.as_entered_value || o.asEnteredValue,
        asEnteredUnit: o.as_entered_unit || o.asEnteredUnit,
      })),
    };
  },
};

// 3. Tool: get_calculated_metrics
export const getCalculatedMetricsTool: FormaTool = {
  name: 'get_calculated_metrics',
  description:
    'Calculate deterministic clinical health metrics (BMI, BMR, TDEE, Caloric Targets) with clinical guardrails.',
  permissionClass: 'read-only',
  inputSchema: z.object({
    formula: z.enum(['bmi', 'tdee']),
    weightKg: z.number().positive().max(500),
    heightCm: z.number().positive().max(300),
    ageYears: z.number().min(18).max(120).optional(),
    sex: z.enum(['male', 'female']).optional(),
    activityLevel: z
      .enum(['sedentary', 'light', 'moderate', 'very_active', 'extra_active'])
      .optional(),
    goalType: z.enum(['weight_loss', 'weight_gain', 'maintenance']).optional(),
  }),
  jsonSchema: {
    type: 'object',
    properties: {
      formula: {
        type: 'string',
        enum: ['bmi', 'tdee'],
        description: 'The formula to execute.',
      },
      weightKg: { type: 'number', description: 'Body weight in kilograms.' },
      heightCm: { type: 'number', description: 'Height in centimeters.' },
      ageYears: { type: 'integer', minimum: 18, description: 'Age in years (adult 18+).' },
      sex: { type: 'string', enum: ['male', 'female'], description: 'Biological sex for calculation.' },
      activityLevel: {
        type: 'string',
        enum: ['sedentary', 'light', 'moderate', 'very_active', 'extra_active'],
        description: 'Physical activity level multiplier.',
      },
      goalType: {
        type: 'string',
        enum: ['weight_loss', 'weight_gain', 'maintenance'],
        description: 'Target direction.',
      },
    },
    required: ['formula', 'weightKg', 'heightCm'],
  },
  async execute(_ctx, input) {
    const calc = new CalculationEngine();
    if (input.formula === 'bmi') {
      const res = calc.calculateBmi(input.weightKg, input.heightCm);
      return {
        formula: 'bmi',
        version: res.formulaId,
        bmi: res.value,
        classification: res.category,
        evidenceType: 'calculated',
      };
    }

    if (input.formula === 'tdee') {
      if (!input.ageYears || !input.sex) {
        throw new Error('ageYears and sex are required for TDEE calculation');
      }
      const bmrRes = calc.calculateBmr({
        weightKg: input.weightKg,
        heightCm: input.heightCm,
        ageYears: input.ageYears,
        sex: input.sex,
      });

      const actMapping: Record<string, any> = {
        sedentary: 'sedentary',
        light: 'lightly_active',
        moderate: 'moderately_active',
        very_active: 'very_active',
        extra_active: 'extremely_active',
      };

      const act = actMapping[input.activityLevel || 'sedentary'] || 'sedentary';
      const tdeeRes = calc.calculateTdee(bmrRes.value, act);

      const targetRes = calc.calculateCalorieTargets({
        tdee: tdeeRes.value,
        sex: input.sex,
      });

      const chosenTarget =
        input.goalType === 'weight_loss'
          ? targetRes.targets.moderateLoss.targetCalories
          : input.goalType === 'weight_gain'
          ? targetRes.targets.moderateGain.targetCalories
          : targetRes.targets.maintenance.targetCalories;

      return {
        formula: 'tdee',
        version: tdeeRes.formulaId,
        bmrKcal: bmrRes.value,
        tdeeKcal: tdeeRes.value,
        targetCaloriesKcal: chosenTarget,
        guardrailWarning: targetRes.guardrailsTriggered.join(', '),
        evidenceType: 'calculated',
      };
    }

    throw new Error(`Unsupported formula '${input.formula}'`);
  },
};

// 4. Tool: get_goals_progress
export const getGoalsProgressTool: FormaTool = {
  name: 'get_goals_progress',
  description: "Retrieve the user's active goals and dynamic observation-backed progress.",
  permissionClass: 'read-only',
  inputSchema: z.object({}),
  jsonSchema: {
    type: 'object',
    properties: {},
  },
  async execute(ctx) {
    if (!ctx.services.goalsService) {
      throw new Error('GoalsService is not available in tool context');
    }
    const goals = await ctx.services.goalsService.listGoals(ctx.userId);
    return {
      count: goals.length,
      goals: goals.map((g: any) => ({
        id: g.id,
        goalType: g.goalType,
        targetMetricTypeCode: g.targetMetricTypeCode,
        startingValue: g.currentVersion?.startingValue,
        targetValue: g.currentVersion?.targetValue,
        currentValue: g.currentValue,
        progressPct: g.progressPct,
        isPrimary: g.isPrimary,
      })),
    };
  },
};

// 5. Tool: get_trends
export const getTrendsTool: FormaTool = {
  name: 'get_trends',
  description: 'Retrieve noise-robust 7-day EMA trend smoothing and sufficiency status.',
  permissionClass: 'read-only',
  inputSchema: z.object({
    days: z.number().int().min(7).max(90).default(30),
  }),
  jsonSchema: {
    type: 'object',
    properties: {
      days: {
        type: 'integer',
        minimum: 7,
        maximum: 90,
        description: 'Analysis window in days (default 30).',
      },
    },
  },
  async execute(ctx, input) {
    if (!ctx.services.analyticsService) {
      throw new Error('AnalyticsService is not available in tool context');
    }
    const trends = await ctx.services.analyticsService.getTrend(ctx.userId, 'weight', input.days);
    return {
      windowDays: input.days,
      trend: trends,
    };
  },
};
