import { z } from 'zod';

export const GoalTypeSchema = z.enum(['weight_loss', 'muscle_gain', 'maintenance', 'general_fitness']);
export type GoalType = z.infer<typeof GoalTypeSchema>;

export const GoalStatusSchema = z.enum(['active', 'achieved', 'abandoned', 'superseded']);
export type GoalStatus = z.infer<typeof GoalStatusSchema>;

/**
 * Physiological sanity bound for a goal's weekly rate. Beyond ±2 kg/week is
 * implausible outside surgical settings; the clinical floor (1%/week,
 * calorie floors) is enforced by the CalculationEngine guardrails.
 */
export const MAX_WEEKLY_RATE_KG = 2;
const weeklyRateSchema = z
  .number()
  .min(-MAX_WEEKLY_RATE_KG)
  .max(MAX_WEEKLY_RATE_KG, `weeklyRate must be within ±${MAX_WEEKLY_RATE_KG} kg/week`);

export const CreateGoalRequestSchema = z.object({
  goalType: GoalTypeSchema.optional(),
  type: GoalTypeSchema.optional(),
  targetMetricTypeCode: z.string().min(1).default('weight'),
  targetValue: z.number().positive(),
  startingValue: z.number().positive().optional(),
  baselineValue: z.number().positive().optional(),
  weeklyRate: weeklyRateSchema.optional(),
  ratePerWeek: weeklyRateSchema.optional(),
  startDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Must be YYYY-MM-DD').optional(),
  targetDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Must be YYYY-MM-DD').optional(),
  rationale: z.string().max(500).optional(),
  isPrimary: z.boolean().default(true)
});
export type CreateGoalRequest = z.infer<typeof CreateGoalRequestSchema>;

export const UpdateGoalVersionRequestSchema = z.object({
  targetValue: z.number().positive(),
  startingValue: z.number().positive().optional(),
  weeklyRate: weeklyRateSchema.optional(),
  targetDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Must be YYYY-MM-DD').optional(),
  rationale: z.string().max(500).optional()
});
export type UpdateGoalVersionRequest = z.infer<typeof UpdateGoalVersionRequestSchema>;

export interface GoalVersion {
  id: string;
  goalId: string;
  userId: string;
  version: number;
  targetValue: number;
  startingValue: number;
  weeklyRate?: number | undefined;
  startDate: string;
  targetDate?: string | undefined;
  rationale?: string | undefined;
  createdAt: string;
}

export interface Goal {
  id: string;
  userId: string;
  goalType: GoalType;
  targetMetricTypeCode: string;
  isPrimary: boolean;
  status: GoalStatus;
  createdAt: string;
  updatedAt: string;
  currentVersion?: GoalVersion | undefined;
  progressPct?: number | undefined;
  currentValue?: number | undefined;
}

/**
 * Single source of truth for goal progress. Callers must pass a REAL measured
 * current value — with no measurement there is no progress to report.
 */
export function computeGoalProgressPct(
  goalType: GoalType | string,
  startValue: number,
  targetValue: number,
  currentValue: number
): number {
  const totalDistance = Math.abs(targetValue - startValue);
  if (totalDistance === 0) return 100;
  const covered =
    goalType === 'weight_loss' || targetValue < startValue
      ? startValue - currentValue
      : currentValue - startValue;
  return Math.round((covered / totalDistance) * 1000) / 10;
}
