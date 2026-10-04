/**
 * Content-Minimized Audit Logging (ADR-009, §20.9)
 *
 * Rules:
 * - Content-minimized: Records action types and resource identifiers, NEVER raw health values or credentials.
 * - Tracks auth events, credential changes, data mutations, exports, purges, and security alerts.
 */

export type AuditActionType =
  | 'auth.login'
  | 'auth.logout'
  | 'auth.refresh_token'
  | 'observation.create'
  | 'observation.supersede'
  | 'observation.void'
  | 'profile.update'
  | 'goal.create'
  | 'goal.update'
  | 'ai.proposal_created'
  | 'ai.proposal_confirmed'
  | 'privacy.export_requested'
  | 'privacy.purge_completed'
  | 'security.access_denied';

export interface AuditEvent {
  id: string;
  userId: string;
  action: AuditActionType;
  resourceId?: string;
  ipAddress?: string;
  userAgent?: string;
  timestamp: string;
  metadata?: Record<string, string | number | boolean>;
}

export class AuditService {
  private static events: AuditEvent[] = [];

  static record(event: Omit<AuditEvent, 'id' | 'timestamp'>): AuditEvent {
    const auditEvent: AuditEvent = {
      ...event,
      id: `audit_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`,
      timestamp: new Date().toISOString(),
    };
    this.events.push(auditEvent);
    return auditEvent;
  }

  static getEventsForUser(userId: string): AuditEvent[] {
    return this.events.filter((e) => e.userId === userId);
  }
}
