import { z } from 'zod';

export const EpistemicClassSchema = z.enum(['measured', 'calculated', 'estimated', 'asserted']);
export type EpistemicClass = z.infer<typeof EpistemicClassSchema>;

export const OriginTypeSchema = z.enum([
  'manual_entry',
  'ai_extraction',
  'system_calculation',
  'user_correction',
  'device_import'
]);
export type OriginType = z.infer<typeof OriginTypeSchema>;

export const CreateObservationRequestSchema = z.object({
  typeCode: z.string().min(1),
  value: z.number().positive('Value must be positive'),
  unit: z.string().min(1),
  observedAt: z.string().datetime({ offset: true }).or(z.string().regex(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)),
  timeZone: z.string().default('UTC'),
  originType: OriginTypeSchema.default('manual_entry'),
  epistemicClass: EpistemicClassSchema.default('measured'),
  actor: z.string().default('user'),
  confidenceScore: z.number().min(0).max(1).default(1.0),
  sourceArtifactId: z.string().uuid().optional(),
  reviewState: z.enum(['unreviewed', 'user_reviewed', 'user_corrected']).default('user_reviewed')
});

export type CreateObservationRequest = z.infer<typeof CreateObservationRequestSchema>;
export type CreateObservationInput = z.input<typeof CreateObservationRequestSchema>;

export const SupersedeObservationRequestSchema = z.object({
  previousObservationId: z.string().uuid(),
  newValue: z.number().positive(),
  newUnit: z.string().min(1),
  correctionReason: z.string().min(1),
  observedAt: z.string().optional()
});

export type SupersedeObservationRequest = z.infer<typeof SupersedeObservationRequestSchema>;

export const VoidObservationRequestSchema = z.object({
  observationId: z.string().uuid(),
  reason: z.string().min(1)
});

export type VoidObservationRequest = z.infer<typeof VoidObservationRequestSchema>;

export const QueryObservationsFilterSchema = z.object({
  typeCode: z.string().optional(),
  status: z.enum(['active', 'superseded', 'voided', 'all']).default('active'),
  fromDate: z.string().optional(),
  toDate: z.string().optional(),
  limit: z.coerce.number().min(1).max(100).default(50).optional()
});

export interface QueryObservationsFilter {
  typeCode?: string | undefined;
  status: 'active' | 'superseded' | 'voided' | 'all';
  fromDate?: string | undefined;
  toDate?: string | undefined;
  limit?: number | undefined;
}
