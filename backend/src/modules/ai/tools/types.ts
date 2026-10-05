import { z } from 'zod';

export type ToolPermissionClass =
  | 'read-only'
  | 'safe-write'
  | 'sensitive-write'
  | 'destructive';

export interface ToolExecutionContext {
  userId: string;
  correlationId: string;
  services: {
    snapshotService?: any;
    goalsService?: any;
    calculationEngine?: any;
    measurementsService?: any;
    analyticsService?: any;
  };
}

export interface FormaTool<TInput = any, TOutput = any> {
  name: string;
  description: string;
  permissionClass: ToolPermissionClass;
  inputSchema: z.ZodType<TInput>;
  jsonSchema: Record<string, unknown>;
  execute(ctx: ToolExecutionContext, input: TInput): Promise<TOutput>;
}

export interface ToolExecutionReceipt {
  toolName: string;
  callId: string;
  permissionClass: ToolPermissionClass;
  success: boolean;
  result: Record<string, unknown>;
  latencyMs: number;
  error?: string | undefined;
}
