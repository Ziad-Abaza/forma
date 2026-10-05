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

/**
 * PUBLIC request schema for the manual-entry route.
 * Provenance is NEVER client-supplied — the route stamps it based on how the
 * request arrived (manual user entry). A client that claims 'measured' or a
 * confidence score could otherwise lie about provenance.
 * `observedAt` omitted means "the observation is happening now".
 * `timeZone` omitted is derived from the user's own observation history,
 * with an explicit 'UTC' last resort only when no history exists.
 */
export const CreateObservationRequestSchema = z.object({
  typeCode: z.string().min(1),
  value: z.number().positive('Value must be positive'),
  unit: z.string().min(1),
  observedAt: z
    .string()
    .datetime({ offset: true })
    .or(z.string().regex(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/))
    .default(() => new Date().toISOString()),
  timeZone: z.string().optional(),
  sourceArtifactId: z.string().uuid().optional()
});

export type CreateObservationRequest = z.infer<typeof CreateObservationRequestSchema>;
export type CreateObservationInput = z.input<typeof CreateObservationRequestSchema>;

/**
 * INTERNAL input for MeasurementsService.recordObservation — provenance is
 * mandatory and explicit for every write path (assistant proposals,
 * extraction commits, corrections). No field may silently default.
 */
export const RecordObservationInputSchema = CreateObservationRequestSchema.extend({
  originType: OriginTypeSchema,
  epistemicClass: EpistemicClassSchema,
  actor: z.string().min(1),
  confidenceScore: z.number().min(0).max(1),
  reviewState: z.enum(['unreviewed', 'user_reviewed', 'user_corrected'])
});

export type RecordObservationInput = z.input<typeof RecordObservationInputSchema>;

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
