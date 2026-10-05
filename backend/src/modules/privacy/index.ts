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

// Register core Phase 1 modules
PrivacyOrchestrator.registerModule(IdentityPrivacyContract);
PrivacyOrchestrator.registerModule(ProfilePrivacyContract);
PrivacyOrchestrator.registerModule(MeasurementsPrivacyContract);
