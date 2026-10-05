import { z } from 'zod';
import { EpistemicClass } from '../measurements/contracts.js';

export type ImageKind =
  | 'body_composition_report'
  | 'scale_display'
  | 'tape_measurement_sheet'
  | 'nutrition_label'
  | 'food_image'
  | 'clinical_document'
  | 'unknown';

export type DraftStatus = 'draft' | 'reviewed' | 'committed' | 'discarded';

export interface ExtractedField {
  typeCode: string;
  rawLabel: string;
  extractedValue: number;
  unit: string;
  canonicalValue: number;
  canonicalUnit: string;
  confidenceScore: number;
  qualityFlags: string[];
  epistemicClass: EpistemicClass;
  userEditedValue?: number | null;
  userEditedUnit?: string | null;
  isApproved: boolean;
}

export interface MediaArtifact {
  id: string;
  userId: string;
  mimeType: string;
  byteSize: number;
  fileHash: string;
  storagePath: string;
  imageKind: ImageKind;
  status: 'uploaded' | 'processing' | 'extracted' | 'retained' | 'deleted';
  metadata: Record<string, any>;
  createdAt: string;
  deletedAt?: string | null;
}

export interface ExtractionDraft {
  id: string;
  userId: string;
  mediaArtifactId: string | null;
  imageKind: ImageKind;
  status: DraftStatus;
  extractedFields: ExtractedField[];
  overallConfidence: number;
  requiresFieldAttention: boolean;
  consistencyFlags: string[];
  sessionId?: string | null;
  createdAt: string;
  updatedAt: string;
  committedAt?: string | null;
}

export const UploadAndExtractRequestSchema = z.object({
  imageBase64: z.string().min(1, 'Base64 image content is required'),
  mimeType: z.enum(['image/jpeg', 'image/png', 'image/webp']).default('image/jpeg'),
  imageKindHint: z.enum([
    'body_composition_report',
    'scale_display',
    'tape_measurement_sheet',
    'nutrition_label',
    'food_image',
    'clinical_document',
    'unknown'
  ]).optional()
});

export type UploadAndExtractRequest = z.input<typeof UploadAndExtractRequestSchema>;

export const UpdateDraftFieldSchema = z.object({
  fieldIndex: z.number().int().min(0),
  userEditedValue: z.number().positive().optional(),
  userEditedUnit: z.string().min(1).optional(),
  isApproved: z.boolean().optional()
});

export type UpdateDraftFieldRequest = z.infer<typeof UpdateDraftFieldSchema>;

export const CommitDraftRequestSchema = z.object({
  deleteSourceImage: z.boolean().default(true),
  observedAt: z.string().datetime({ offset: true }).or(z.string().regex(/^\d{4}-\d{2}-\d{2}/)).optional()
});

export type CommitDraftRequest = z.input<typeof CommitDraftRequestSchema>;
