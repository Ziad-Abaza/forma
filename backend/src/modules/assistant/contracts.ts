import { z } from 'zod';

export type EvidenceType = 'retrieved' | 'calculated' | 'estimated' | 'inferred' | 'recommended' | 'unknown';

export interface EvidenceClaim {
  claimText: string;
  evidenceType: EvidenceType;
  source?: string;
  value?: number | string;
}

export interface Conversation {
  id: string;
  userId: string;
  title: string;
  summary: string | null;
  rollingSummary: string | null;
  metadata: Record<string, unknown>;
  createdAt: string;
  updatedAt: string;
}

export interface ConversationMessage {
  id: string;
  conversationId: string;
  userId: string;
  role: 'user' | 'assistant' | 'system' | 'tool';
  content: string;
  evidenceClaims: EvidenceClaim[];
  proposals: ActionProposal[];
  tokenCount: number;
  safetyCategory: string;
  createdAt: string;
}

export type ActionType = 'log_measurement' | 'update_goal' | 'save_memory';

export interface ActionReceipt {
  receiptId: string;
  proposalId: string;
  actionType: ActionType;
  committedAt: string;
  entityId: string;
  entityType: string;
  provenance: string;
  summary: string;
}

export interface ActionProposalDiffPreview {
  before?: Record<string, any> | null;
  after: Record<string, any>;
  description: string;
}

export interface ActionProposal {
  id: string;
  userId: string;
  conversationId: string | null;
  messageId: string | null;
  actionType: ActionType;
  parameters: Record<string, any>;
  diffPreview: ActionProposalDiffPreview;
  humanReadableSummary: string;
  status: 'pending' | 'confirmed' | 'declined' | 'expired' | 'executed' | 'failed';
  idempotencyKey: string;
  expiresAt: string;
  executedAt?: string | null;
  receipt?: ActionReceipt | null;
  createdAt: string;
}

export interface AssistantMemory {
  id: string;
  userId: string;
  category: 'preference' | 'fact' | 'routine' | 'constraint';
  key: string;
  value: string;
  confidence: number;
  source: string;
  provenanceId?: string | null;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

export const ChatRequestSchema = z.object({
  conversationId: z.string().uuid().optional(),
  message: z.string().min(1, 'Message cannot be empty'),
  stream: z.boolean().default(false)
});

export type ChatRequest = z.input<typeof ChatRequestSchema>;

export const ConfirmProposalSchema = z.object({
  idempotencyKey: z.string().min(1).optional()
});

export type ConfirmProposalRequest = z.infer<typeof ConfirmProposalSchema>;

export const SaveMemorySchema = z.object({
  category: z.enum(['preference', 'fact', 'routine', 'constraint']),
  key: z.string().min(1),
  value: z.string().min(1),
  confidence: z.number().min(0).max(1).default(1.0)
});

export type SaveMemoryRequest = z.input<typeof SaveMemorySchema>;
