import { withUserContext } from '../../core/database/index.js';
import type { ExportableModule, DeletableModule } from '../privacy/index.js';
import { SnapshotEngine } from './snapshot.js';
import { TrendEngine } from './trends.js';
import type { HealthSnapshot, TrendAnalysis } from './contracts.js';
import { MeasurementsRepository } from '../measurements/repository.js';

export class AnalyticsService implements ExportableModule, DeletableModule {
  public readonly moduleName = 'analytics';
  private readonly snapshotEngine = new SnapshotEngine();

  public async getSnapshot(userId: string): Promise<HealthSnapshot> {
    return this.snapshotEngine.getOrRefreshSnapshot(userId);
  }

  public async reconcileSnapshot(userId: string): Promise<{ isDriftDetected: boolean; diffDetails?: string }> {
    return this.snapshotEngine.reconcile(userId);
  }

  public async getTrend(userId: string, typeCode: string, windowDays: number = 30): Promise<TrendAnalysis> {
    return withUserContext(userId, async (client) => {
      const obs = await MeasurementsRepository.queryObservations(client, userId, {
        typeCode,
        status: 'active',
        limit: 100
      });

      const points = obs.map((o) => ({
        observedAt: o.observed_at,
        value: Number(o.canonical_value)
      }));

      return TrendEngine.calculateTrend(typeCode, points, windowDays);
    });
  }

  public async exportData(userId: string): Promise<Record<string, unknown>> {
    return withUserContext(userId, async (client) => {
      const snapRes = await client.query(`SELECT * FROM health_snapshots WHERE user_id = $1`, [userId]);
      const rollupsRes = await client.query(`SELECT * FROM metric_rollups WHERE user_id = $1`, [userId]);
      const flagsRes = await client.query(`SELECT * FROM anomaly_flags WHERE user_id = $1`, [userId]);

      return {
        snapshot: snapRes.rows[0] || null,
        rollups: rollupsRes.rows,
        anomalies: flagsRes.rows
      };
    });
  }

  public async purgeData(userId: string): Promise<void> {
    return withUserContext(userId, async (client) => {
      await client.query(`DELETE FROM anomaly_flags WHERE user_id = $1`, [userId]);
      await client.query(`DELETE FROM metric_rollups WHERE user_id = $1`, [userId]);
      await client.query(`DELETE FROM health_snapshots WHERE user_id = $1`, [userId]);
    });
  }
}
