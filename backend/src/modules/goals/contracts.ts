import { z } from 'zod';

export const GoalTypeSchema = z.enum(['weight_loss', 'muscle_gain', 'maintenance', 'general_fitness']);
export type GoalType = z.infer<typeof GoalTypeSchema>;

export const GoalStatusSchema = z.enum(['active', 'achieved', 'abandoned', 'superseded']);
export type GoalStatus = z.infer<typeof GoalStatusSchema>;

export const CreateGoalRequestSchema = z.object({
  goalType: GoalTypeSchema,
  targetMetricTypeCode: z.string().min(1),
  targetValue: z.number().positive(),
  startingValue: z.number().positive(),
  weeklyRate: z.number().optional(),
  startDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Must be YYYY-MM-DD'),
  targetDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Must be YYYY-MM-DD').optional(),
  rationale: z.string().max(500).optional(),
  isPrimary: z.boolean().default(true)
});
export type CreateGoalRequest = z.infer<typeof CreateGoalRequestSchema>;

export const UpdateGoalVersionRequestSchema = z.object({
  targetValue: z.number().positive(),
  startingValue: z.number().positive().optional(),
  weeklyRate: z.number().optional(),
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
