import { z } from 'zod';

export const RegisterRequestSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8, 'Password must be at least 8 characters long'),
  dateOfBirth: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Date of birth must be YYYY-MM-DD'),
  heightCm: z.number().min(80).max(260),
  sexForCalculation: z.enum(['male', 'female', 'unspecified']).default('unspecified'),
  locale: z.enum(['en', 'ar']).default('en'),
  numeralSystem: z.enum(['western', 'eastern_arabic']).default('western'),
  consents: z.object({
    termsOfService: z.boolean().refine(val => val === true, 'Terms of service must be accepted'),
    healthDataProcessing: z.boolean().refine(val => val === true, 'Health data processing consent is required'),
    aiThirdPartyProcessing: z.boolean().default(true)
  })
});

export type RegisterRequest = z.infer<typeof RegisterRequestSchema>;

export const LoginRequestSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
  deviceInfo: z.record(z.unknown()).optional()
});

export type LoginRequest = z.infer<typeof LoginRequestSchema>;

export const RefreshTokenRequestSchema = z.object({
  refreshToken: z.string().min(32)
});

export type RefreshTokenRequest = z.infer<typeof RefreshTokenRequestSchema>;

export const UpdatePreferencesRequestSchema = z.object({
  locale: z.enum(['en', 'ar']).optional(),
  numeralSystem: z.enum(['western', 'eastern_arabic']).optional()
});

export type UpdatePreferencesRequest = z.infer<typeof UpdatePreferencesRequestSchema>;

export const UserSummarySchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  role: z.string(),
  locale: z.string(),
  numeralSystem: z.string(),
  emailVerified: z.boolean()
});

export type UserSummary = z.infer<typeof UserSummarySchema>;

export const AuthResponseSchema = z.object({
  user: UserSummarySchema,
  tokens: z.object({
    accessToken: z.string(),
    refreshToken: z.string(),
    expiresInSeconds: z.number()
  })
});

export type AuthResponse = z.infer<typeof AuthResponseSchema>;

