import { FormaTool, ToolExecutionContext, ToolExecutionReceipt, ToolPermissionClass } from './types.js';
import {
  getHealthSnapshotTool,
  queryObservationsTool,
  getCalculatedMetricsTool,
  getGoalsProgressTool,
  getTrendsTool,
} from './definitions.js';

export class ToolRegistry {
  private readonly tools: Map<string, FormaTool> = new Map();

  constructor() {
    this.registerTool(getHealthSnapshotTool);
    this.registerTool(queryObservationsTool);
    this.registerTool(getCalculatedMetricsTool);
    this.registerTool(getGoalsProgressTool);
    this.registerTool(getTrendsTool);
  }

  public registerTool(tool: FormaTool): void {
    this.tools.set(tool.name, tool);
  }

  public getTool(name: string): FormaTool | undefined {
    return this.tools.get(name);
  }

  public getAllTools(): FormaTool[] {
    return Array.from(this.tools.values());
  }

  public getDeclarations(allowedPermissions?: ToolPermissionClass[]): Array<{
    name: string;
    description: string;
    parameters: Record<string, unknown>;
  }> {
    const list = this.getAllTools();
    const filtered = allowedPermissions
      ? list.filter((t) => allowedPermissions.includes(t.permissionClass))
      : list;

    return filtered.map((t) => ({
      name: t.name,
      description: t.description,
      parameters: t.jsonSchema,
    }));
  }
}

export class ToolExecutor {
  constructor(private readonly registry: ToolRegistry) {}

  public async executeToolCall(
    callId: string,
    toolName: string,
    rawArgs: Record<string, unknown>,
    ctx: ToolExecutionContext,
    allowedPermissions?: ToolPermissionClass[]
  ): Promise<ToolExecutionReceipt> {
    const startTime = Date.now();
    const tool = this.registry.getTool(toolName);

    if (!tool) {
      return {
        toolName,
        callId,
        permissionClass: 'read-only',
        success: false,
        result: {},
        latencyMs: Date.now() - startTime,
        error: `Tool '${toolName}' is not registered`,
      };
    }

    if (allowedPermissions && !allowedPermissions.includes(tool.permissionClass)) {
      return {
        toolName,
        callId,
        permissionClass: tool.permissionClass,
        success: false,
        result: {},
        latencyMs: Date.now() - startTime,
        error: `Tool '${toolName}' permission '${tool.permissionClass}' is not permitted for this turn`,
      };
    }

    // Invariant: LLM cannot provide userId. Enforce server-injected identity.
    if ('userId' in rawArgs || 'user_id' in rawArgs) {
      delete rawArgs.userId;
      delete rawArgs.user_id;
    }

    try {
      const parsedInput = tool.inputSchema.parse(rawArgs);
      const output = await tool.execute(ctx, parsedInput);

      return {
        toolName,
        callId,
        permissionClass: tool.permissionClass,
        success: true,
        result: output,
        latencyMs: Date.now() - startTime,
      };
    } catch (err: any) {
      return {
        toolName,
        callId,
        permissionClass: tool.permissionClass,
        success: false,
        result: {},
        latencyMs: Date.now() - startTime,
        error: err.message || 'Tool execution failed',
      };
    }
  }
}
