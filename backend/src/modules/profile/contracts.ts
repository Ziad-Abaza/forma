import { z } from 'zod';

export const UpdateProfileRequestSchema = z.object({
  dateOfBirth: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Must be YYYY-MM-DD').optional(),
  heightCm: z.number().min(80).max(260).optional(),
  sexForCalculation: z.enum(['male', 'female', 'unspecified']).optional(),
  activityLevel: z.enum(['sedentary', 'lightly_active', 'moderately_active', 'very_active', 'extra_active']).optional(),
  experienceLevel: z.enum(['beginner', 'intermediate', 'advanced']).optional(),
  constraints: z.array(z.string()).optional(),
  preferences: z.record(z.unknown()).optional()
});

export type UpdateProfileRequest = z.infer<typeof UpdateProfileRequestSchema>;

export interface ProfileResponse {
  userId: string;
  dateOfBirth: string;
  sexForCalculation: string;
  heightCm: number;
  activityLevel: string;
  experienceLevel: string;
  constraints: string[];
  preferences: Record<string, unknown>;
  createdAt: Date;
  updatedAt: Date;
}

export interface ProfileHistoryEntry {
  id: string;
  userId: string;
  attributeName: string;
  oldValue: unknown;
  newValue: unknown;
  effectiveFrom: Date;
  actor: string;
}
