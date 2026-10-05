import { withUserContext, withPurgeContext, withSystemContext } from '../../core/database/index.js';
import { AuditService } from '../audit/index.js';

export interface ExportPayload {
  module: string;
  version: string;
  exportedAt: string;
  data: Record<string, unknown> | unknown[];
}

export interface DeletionResult {
  module: string;
  recordsDeleted: number;
  success: boolean;
  error?: string;
}

export interface ModulePrivacyContract {
  moduleName: string;
  exportData(userId: string): Promise<ExportPayload>;
  purgeUserData(userId: string): Promise<DeletionResult>;
}

export class PrivacyOrchestrator {
  private static registeredModules: ModulePrivacyContract[] = [];

  static registerModule(module: ModulePrivacyContract): void {
    if (!this.registeredModules.some(m => m.moduleName === module.moduleName)) {
      this.registeredModules.push(module);
    }
  }

  static getRegisteredModules(): ModulePrivacyContract[] {
    return [...this.registeredModules];
  }

  /**
   * Executes a portable export of all user data across all registered modules.
   * Excludes all secret tokens, passwords, and API keys.
   */
  static async exportAllUserData(
    userId: string,
    correlationId: string
  ): Promise<{ exportDate: string; userId: string; modules: Record<string, unknown> }> {
    const exportResult: Record<string, unknown> = {};

    for (const mod of this.registeredModules) {
      const payload = await mod.exportData(userId);
      exportResult[payload.module] = payload.data;
    }

    await AuditService.recordEvent({
      userId,
      actorType: 'user',
      action: 'privacy_data_export_generated',
      entityType: 'privacy_export',
      entityId: userId,
      correlationId,
      status: 'success',
      metadata: { modulesIncluded: Object.keys(exportResult) }
    });

    return {
      exportDate: new Date().toISOString(),
      userId,
      modules: exportResult
    };
  }

  /**
   * Executes an irreversible GDPR/privacy account purge across all registered modules.
   * Utilizes withPurgeContext to satisfy database-level append-only observation immutability bypass.
   */
  static async purgeUserAccount(
    userId: string,
    correlationId: string
  ): Promise<{ success: boolean; results: DeletionResult[] }> {
    const results: DeletionResult[] = [];

    // Run purge for all domain modules
    for (const mod of this.registeredModules) {
      try {
        const res = await mod.purgeUserData(userId);
        results.push(res);
      } catch (err: any) {
        results.push({
          module: mod.moduleName,
          recordsDeleted: 0,
          success: false,
          error: err.message
        });
      }
    }

    // Finally delete the user root record under system context
    await withSystemContext(async (client) => {
      await client.query('DELETE FROM users WHERE id = $1', [userId]);
    });

    await AuditService.recordEvent({
      userId: null,
      actorType: 'user',
      action: 'privacy_account_purged',
      entityType: 'user',
      entityId: userId,
      correlationId,
      status: 'success',
      metadata: { results }
    });

    return {
      success: results.every(r => r.success),
      results
    };
  }
}

// 1. Identity Module Privacy Contract
export const IdentityPrivacyContract: ModulePrivacyContract = {
  moduleName: 'identity',
  async exportData(userId: string): Promise<ExportPayload> {
    return await withUserContext(userId, async (client) => {
      const userRes = await client.query(
        'SELECT id, email, role, locale, numeral_system, email_verified, created_at FROM users WHERE id = $1',
        [userId]
      );
      const consentRes = await client.query(
        'SELECT policy_type, version, granted, granted_at, withdrawn_at FROM consents WHERE user_id = $1',
        [userId]
      );
      const sessionRes = await client.query(
        'SELECT id, device_info, is_revoked, expires_at, created_at FROM sessions WHERE user_id = $1',
        [userId]
      );

      return {
        module: 'identity',
        version: '1.0.0',
        exportedAt: new Date().toISOString(),
        data: {
          account: userRes.rows[0],
          consents: consentRes.rows,
          sessions: sessionRes.rows
        }
      };
    });
  },
  async purgeUserData(userId: string): Promise<DeletionResult> {
    return await withPurgeContext(userId, async (client) => {
      const s = await client.query('DELETE FROM sessions WHERE user_id = $1', [userId]);
      const c = await client.query('DELETE FROM consents WHERE user_id = $1', [userId]);
      const cr = await client.query('DELETE FROM credentials WHERE user_id = $1', [userId]);
      return {
        module: 'identity',
        recordsDeleted: (s.rowCount || 0) + (c.rowCount || 0) + (cr.rowCount || 0),
        success: true
      };
    });
  }
};

// 2. Profile Module Privacy Contract
export const ProfilePrivacyContract: ModulePrivacyContract = {
  moduleName: 'profile',
  async exportData(userId: string): Promise<ExportPayload> {
    return await withUserContext(userId, async (client) => {
      const profile = await client.query('SELECT * FROM profiles WHERE user_id = $1', [userId]);
      const history = await client.query('SELECT * FROM profile_history WHERE user_id = $1 ORDER BY effective_from ASC', [userId]);
      return {
        module: 'profile',
        version: '1.0.0',
        exportedAt: new Date().toISOString(),
        data: {
          profile: profile.rows[0] || null,
          history: history.rows
        }
      };
    });
  },
  async purgeUserData(userId: string): Promise<DeletionResult> {
    return await withPurgeContext(userId, async (client) => {
      const h = await client.query('DELETE FROM profile_history WHERE user_id = $1', [userId]);
      const p = await client.query('DELETE FROM profiles WHERE user_id = $1', [userId]);
      return {
        module: 'profile',
        recordsDeleted: (h.rowCount || 0) + (p.rowCount || 0),
        success: true
      };
    });
  }
};

// 3. Measurements Module Privacy Contract
export const MeasurementsPrivacyContract: ModulePrivacyContract = {
  moduleName: 'measurements',
  async exportData(userId: string): Promise<ExportPayload> {
    return await withUserContext(userId, async (client) => {
      const obs = await client.query('SELECT * FROM observations WHERE user_id = $1 ORDER BY observed_at ASC', [userId]);
      const prov = await client.query('SELECT * FROM provenance_records WHERE user_id = $1 ORDER BY observed_at ASC', [userId]);
      return {
        module: 'measurements',
        version: '1.0.0',
        exportedAt: new Date().toISOString(),
        data: {
          observations: obs.rows,
          provenance: prov.rows
        }
      };
    });
  },
  async purgeUserData(userId: string): Promise<DeletionResult> {
    return await withPurgeContext(userId, async (client) => {
      const o = await client.query('DELETE FROM observations WHERE user_id = $1', [userId]);
      const p = await client.query('DELETE FROM provenance_records WHERE user_id = $1', [userId]);
      return {
        module: 'measurements',
        recordsDeleted: (o.rowCount || 0) + (p.rowCount || 0),
        success: true
      };
    });
  }
};

export interface ExportableModule {
  moduleName: string;
  exportData(userId: string): Promise<Record<string, unknown>>;
}

export interface DeletableModule {
  moduleName: string;
  purgeData(userId: string): Promise<void>;
}

// 4. Goals Module Privacy Contract
export const GoalsPrivacyContract: ModulePrivacyContract = {
  moduleName: 'goals',
  async exportData(userId: string): Promise<ExportPayload> {
    return await withUserContext(userId, async (client) => {
      const goals = await client.query('SELECT * FROM goals WHERE user_id = $1 ORDER BY created_at ASC', [userId]);
      const versions = await client.query('SELECT * FROM goal_versions WHERE user_id = $1 ORDER BY created_at ASC', [userId]);
      return {
        module: 'goals',
        version: '1.0.0',
        exportedAt: new Date().toISOString(),
        data: {
          goals: goals.rows,
          goalVersions: versions.rows
        }
      };
    });
  },
  async purgeUserData(userId: string): Promise<DeletionResult> {
    return await withPurgeContext(userId, async (client) => {
      const v = await client.query('DELETE FROM goal_versions WHERE user_id = $1', [userId]);
      const g = await client.query('DELETE FROM goals WHERE user_id = $1', [userId]);
      return {
        module: 'goals',
        recordsDeleted: (v.rowCount || 0) + (g.rowCount || 0),
        success: true
      };
    });
  }
};

// 5. Analytics Module Privacy Contract
export const AnalyticsPrivacyContract: ModulePrivacyContract = {
  moduleName: 'analytics',
  async exportData(userId: string): Promise<ExportPayload> {
    return await withUserContext(userId, async (client) => {
      const snap = await client.query('SELECT * FROM health_snapshots WHERE user_id = $1', [userId]);
      const rollups = await client.query('SELECT * FROM metric_rollups WHERE user_id = $1', [userId]);
      const flags = await client.query('SELECT * FROM anomaly_flags WHERE user_id = $1', [userId]);
      return {
        module: 'analytics',
        version: '1.0.0',
        exportedAt: new Date().toISOString(),
        data: {
          snapshot: snap.rows[0] || null,
          rollups: rollups.rows,
          anomalies: flags.rows
        }
      };
    });
  },
  async purgeUserData(userId: string): Promise<DeletionResult> {
    return await withPurgeContext(userId, async (client) => {
      const a = await client.query('DELETE FROM anomaly_flags WHERE user_id = $1', [userId]);
      const r = await client.query('DELETE FROM metric_rollups WHERE user_id = $1', [userId]);
      const s = await client.query('DELETE FROM health_snapshots WHERE user_id = $1', [userId]);
      return {
        module: 'analytics',
        recordsDeleted: (a.rowCount || 0) + (r.rowCount || 0) + (s.rowCount || 0),
        success: true
      };
    });
  }
};

// 6. AI Platform Traces & Credentials Privacy Contract
export const AITracesPrivacyContract: ModulePrivacyContract = {
  moduleName: 'ai_traces',
  async exportData(userId: string): Promise<ExportPayload> {
    return await withUserContext(userId, async (client) => {
      const traces = await client.query(
        'SELECT id, correlation_id, provider, model_id, task_class, intent_class, context_tier, context_manifest, safety_category, created_at FROM ai_traces WHERE user_id = $1 ORDER BY created_at ASC',
        [userId]
      );
      const creds = await client.query(
        'SELECT id, provider, key_fingerprint, is_active, created_at FROM user_ai_credentials WHERE user_id = $1',
        [userId]
      );
      return {
        module: 'ai_traces',
        version: '1.0.0',
        exportedAt: new Date().toISOString(),
        data: {
          traces: traces.rows,
          byokCredentials: creds.rows,
        },
      };
    });
  },
  async purgeUserData(userId: string): Promise<DeletionResult> {
    return await withPurgeContext(userId, async (client) => {
      const t = await client.query('DELETE FROM ai_traces WHERE user_id = $1', [userId]);
      const c = await client.query('DELETE FROM user_ai_credentials WHERE user_id = $1', [userId]);
      return {
        module: 'ai_traces',
        recordsDeleted: (t.rowCount || 0) + (c.rowCount || 0),
        success: true,
      };
    });
  },
};

// Register Phase 1, Phase 2, and Phase 3 modules
PrivacyOrchestrator.registerModule(IdentityPrivacyContract);
PrivacyOrchestrator.registerModule(ProfilePrivacyContract);
PrivacyOrchestrator.registerModule(MeasurementsPrivacyContract);
PrivacyOrchestrator.registerModule(GoalsPrivacyContract);
PrivacyOrchestrator.registerModule(AnalyticsPrivacyContract);
PrivacyOrchestrator.registerModule(AITracesPrivacyContract);


