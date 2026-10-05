import { z } from 'zod';

export const IntegrationProviderSchema = z.enum([
  'apple_health',
  'health_connect',
  'garmin',
  'withings',
  'oura',
  'fitbit'
]);
export type IntegrationProvider = z.infer<typeof IntegrationProviderSchema>;

export const SyncRecordPayloadSchema = z.object({
  externalRecordId: z.string().min(1),
  typeCode: z.string().min(1),
  value: z.number(),
  unit: z.string().min(1),
  recordedAt: z.string().datetime(),
  sourceDeviceId: z.string().optional(),
  epistemicClass: z.enum(['measured', 'calculated', 'estimated', 'asserted']).default('measured'),
  rawMetadata: z.record(z.unknown()).optional()
});
export type SyncRecordPayload = z.infer<typeof SyncRecordPayloadSchema>;

export const SyncBatchRequestSchema = z.object({
  provider: IntegrationProviderSchema,
  records: z.array(SyncRecordPayloadSchema).max(1000),
  syncCursor: z.string().optional()
});
export type SyncBatchRequest = z.infer<typeof SyncBatchRequestSchema>;

export interface SyncBatchResult {
  batchId: string;
  provider: IntegrationProvider;
  totalProcessed: number;
  inserted: number;
  deduplicated: number;
  supersededConflicts: number;
  rejected: number;
  syncCursor?: string | undefined;
}

export interface IntegrationConnectionRecord {
  id: string;
  userId: string;
  provider: IntegrationProvider;
  status: 'connected' | 'revoked' | 'paused' | 'error';
  scopes: string[];
  metadata: Record<string, unknown>;
  lastSyncedAt?: string | undefined;
  createdAt: string;
  updatedAt: string;
}
