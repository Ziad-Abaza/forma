import type { PoolClient } from 'pg';
import { getPool } from '../../core/database/index.js';

export interface AuditEventInput {
  userId?: string | null | undefined;
  actorType: 'user' | 'system' | 'admin';
  action: string;
  entityType: string;
  entityId: string;
  correlationId: string;
  ipAddress?: string | null | undefined;
  status: 'success' | 'failure';
  metadata?: Record<string, unknown> | undefined;
}

// Prohibited sensitive keys in audit metadata
const PROHIBITED_KEYS = [
  'password',
  'passwordHash',
  'token',
  'refreshToken',
  'secret',
  'apiKey',
  'value',
  'canonicalValue',
  'originalValue',
  'height',
  'weight',
  'bodyFat'
];

export function sanitizeAuditMetadata(metadata?: Record<string, unknown>): Record<string, unknown> {
  if (!metadata) return {};
  const sanitized: Record<string, unknown> = {};

  for (const [k, v] of Object.entries(metadata)) {
    const lowerKey = k.toLowerCase();
    if (PROHIBITED_KEYS.some(pk => lowerKey.includes(pk.toLowerCase()))) {
      sanitized[k] = '[REDACTED_SENSITIVE_DATA]';
    } else if (typeof v === 'object' && v !== null) {
      sanitized[k] = sanitizeAuditMetadata(v as Record<string, unknown>);
    } else {
      sanitized[k] = v;
    }
  }

  return sanitized;
}

export class AuditService {
  /**
   * Records a content-free audit event.
   * Can accept an existing PoolClient (for transaction inclusion) or uses the connection pool.
   */
  static async recordEvent(event: AuditEventInput, client?: PoolClient): Promise<void> {
    const sanitizedMetadata = sanitizeAuditMetadata(event.metadata);
    const query = `
      INSERT INTO audit_logs (
        user_id, actor_type, action, entity_type, entity_id, correlation_id, ip_address, status, metadata
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
    `;
    const params = [
      event.userId ?? null,
      event.actorType,
      event.action,
      event.entityType,
      event.entityId,
      event.correlationId,
      event.ipAddress ?? null,
      event.status,
      JSON.stringify(sanitizedMetadata)
    ];

    if (client) {
      await client.query(query, params);
    } else {
      const pool = getPool();
      await pool.query(query, params);
    }
  }
}
