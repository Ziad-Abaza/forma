import { withUserContext } from '../../core/database/index.js';
import type { Goal, GoalVersion, CreateGoalRequest, UpdateGoalVersionRequest } from './contracts.js';

export class GoalsRepository {
  public async createGoal(userId: string, data: CreateGoalRequest): Promise<Goal> {
    return withUserContext(userId, async (client) => {
      if (data.isPrimary) {
        await client.query(
          `UPDATE goals SET is_primary = false WHERE user_id = $1`,
          [userId]
        );
      }

      const goalType = data.goalType || data.type || 'weight_loss';
      const startingValue = data.startingValue ?? data.baselineValue ?? data.targetValue;
      const weeklyRate = data.weeklyRate ?? data.ratePerWeek ?? null;
      const startDate = data.startDate || new Date().toISOString().slice(0, 10);
      const metricType = data.targetMetricTypeCode || 'weight';

      const goalRes = await client.query(
        `INSERT INTO goals (user_id, goal_type, target_metric_type_code, is_primary, status)
         VALUES ($1, $2, $3, $4, 'active')
         RETURNING id, user_id, goal_type, target_metric_type_code, is_primary, status, created_at, updated_at`,
        [userId, goalType, metricType, data.isPrimary]
      );
      const goalRow = goalRes.rows[0];

      const versionRes = await client.query(
        `INSERT INTO goal_versions (
           goal_id, user_id, version, target_value, starting_value,
           weekly_rate, start_date, target_date, rationale
         )
         VALUES ($1, $2, 1, $3, $4, $5, $6, $7, $8)
         RETURNING id, goal_id, user_id, version, target_value, starting_value,
                   weekly_rate, start_date, target_date, rationale, created_at`,
        [
          goalRow.id,
          userId,
          data.targetValue,
          startingValue,
          weeklyRate,
          startDate,
          data.targetDate || null,
          data.rationale || null
        ]
      );
      const versionRow = versionRes.rows[0];

      const currentVersion: GoalVersion = {
        id: versionRow.id,
        goalId: versionRow.goal_id,
        userId: versionRow.user_id,
        version: versionRow.version,
        targetValue: Number(versionRow.target_value),
        startingValue: Number(versionRow.starting_value),
        weeklyRate: versionRow.weekly_rate ? Number(versionRow.weekly_rate) : undefined,
        startDate: versionRow.start_date.toISOString ? versionRow.start_date.toISOString().split('T')[0] : String(versionRow.start_date),
        targetDate: versionRow.target_date ? (versionRow.target_date.toISOString ? versionRow.target_date.toISOString().split('T')[0] : String(versionRow.target_date)) : undefined,
        rationale: versionRow.rationale || undefined,
        createdAt: versionRow.created_at.toISOString()
      };

      return {
        id: goalRow.id,
        userId: goalRow.user_id,
        goalType: goalRow.goal_type,
        targetMetricTypeCode: goalRow.target_metric_type_code,
        isPrimary: goalRow.is_primary,
        status: goalRow.status,
        createdAt: goalRow.created_at.toISOString(),
        updatedAt: goalRow.updated_at.toISOString(),
        currentVersion
      };
    });
  }

  public async addGoalVersion(
    userId: string,
    goalId: string,
    data: UpdateGoalVersionRequest
  ): Promise<GoalVersion> {
    return withUserContext(userId, async (client) => {
      // Find latest version
      const maxVerRes = await client.query(
        `SELECT version, starting_value, start_date FROM goal_versions WHERE goal_id = $1 ORDER BY version DESC LIMIT 1`,
        [goalId]
      );
      if (maxVerRes.rows.length === 0) {
        throw new Error('Goal not found');
      }

      const prev = maxVerRes.rows[0];
      const nextVersion = prev.version + 1;
      const startingVal = data.startingValue !== undefined ? data.startingValue : Number(prev.starting_value);
      const startDate = new Date().toISOString().split('T')[0];

      const res = await client.query(
        `INSERT INTO goal_versions (
           goal_id, user_id, version, target_value, starting_value,
           weekly_rate, start_date, target_date, rationale
         )
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
         RETURNING id, goal_id, user_id, version, target_value, starting_value,
                   weekly_rate, start_date, target_date, rationale, created_at`,
        [
          goalId,
          userId,
          nextVersion,
          data.targetValue,
          startingVal,
          data.weeklyRate || null,
          startDate,
          data.targetDate || null,
          data.rationale || null
        ]
      );
      const row = res.rows[0];

      await client.query(`UPDATE goals SET updated_at = NOW() WHERE id = $1`, [goalId]);

      return {
        id: row.id,
        goalId: row.goal_id,
        userId: row.user_id,
        version: row.version,
        targetValue: Number(row.target_value),
        startingValue: Number(row.starting_value),
        weeklyRate: row.weekly_rate ? Number(row.weekly_rate) : undefined,
        startDate: row.start_date.toISOString ? row.start_date.toISOString().split('T')[0] : String(row.start_date),
        targetDate: row.target_date ? (row.target_date.toISOString ? row.target_date.toISOString().split('T')[0] : String(row.target_date)) : undefined,
        rationale: row.rationale || undefined,
        createdAt: row.created_at.toISOString()
      };
    });
  }

  /**
   * Returns the full immutable version history for a goal owned by the user.
   */
  public async listGoalVersions(userId: string, goalId: string): Promise<GoalVersion[]> {
    return withUserContext(userId, async (client) => {
      const res = await client.query(
        `SELECT id, goal_id, user_id, version, target_value, starting_value,
                weekly_rate, start_date, target_date, rationale, created_at
         FROM goal_versions
         WHERE goal_id = $1 AND user_id = $2
         ORDER BY version DESC`,
        [goalId, userId]
      );

      return res.rows.map((row) => ({
        id: row.id,
        goalId: row.goal_id,
        userId: row.user_id,
        version: row.version,
        targetValue: Number(row.target_value),
        startingValue: Number(row.starting_value),
        weeklyRate: row.weekly_rate ? Number(row.weekly_rate) : undefined,
        startDate: row.start_date.toISOString ? row.start_date.toISOString().split('T')[0] : String(row.start_date),
        targetDate: row.target_date ? (row.target_date.toISOString ? row.target_date.toISOString().split('T')[0] : String(row.target_date)) : undefined,
        rationale: row.rationale || undefined,
        createdAt: row.created_at.toISOString()
      }));
    });
  }

  public async getPrimaryGoal(userId: string): Promise<Goal | null> {
    return withUserContext(userId, async (client) => {
      const res = await client.query(
        `SELECT g.id, g.user_id, g.goal_type, g.target_metric_type_code, g.is_primary, g.status,
                g.created_at, g.updated_at,
                v.id as v_id, v.version, v.target_value, v.starting_value, v.weekly_rate,
                v.start_date, v.target_date, v.rationale, v.created_at as v_created_at
         FROM goals g
         LEFT JOIN LATERAL (
           SELECT * FROM goal_versions gv WHERE gv.goal_id = g.id ORDER BY gv.version DESC LIMIT 1
         ) v ON true
         WHERE g.user_id = $1 AND g.is_primary = true AND g.status = 'active'
         LIMIT 1`,
        [userId]
      );

      if (res.rows.length === 0) return null;
      const row = res.rows[0];

      return {
        id: row.id,
        userId: row.user_id,
        goalType: row.goal_type,
        targetMetricTypeCode: row.target_metric_type_code,
        isPrimary: row.is_primary,
        status: row.status,
        createdAt: row.created_at.toISOString(),
        updatedAt: row.updated_at.toISOString(),
        currentVersion: row.v_id ? {
          id: row.v_id,
          goalId: row.id,
          userId: row.user_id,
          version: row.version,
          targetValue: Number(row.target_value),
          startingValue: Number(row.starting_value),
          weeklyRate: row.weekly_rate ? Number(row.weekly_rate) : undefined,
          startDate: row.start_date.toISOString ? row.start_date.toISOString().split('T')[0] : String(row.start_date),
          targetDate: row.target_date ? (row.target_date.toISOString ? row.target_date.toISOString().split('T')[0] : String(row.target_date)) : undefined,
          rationale: row.rationale || undefined,
          createdAt: row.v_created_at.toISOString()
        } : undefined
      };
    });
  }

  public async listGoals(userId: string): Promise<Goal[]> {
    return withUserContext(userId, async (client) => {
      const res = await client.query(
        `SELECT g.id, g.user_id, g.goal_type, g.target_metric_type_code, g.is_primary, g.status,
                g.created_at, g.updated_at,
                v.id as v_id, v.version, v.target_value, v.starting_value, v.weekly_rate,
                v.start_date, v.target_date, v.rationale, v.created_at as v_created_at
         FROM goals g
         LEFT JOIN LATERAL (
           SELECT * FROM goal_versions gv WHERE gv.goal_id = g.id ORDER BY gv.version DESC LIMIT 1
         ) v ON true
         WHERE g.user_id = $1
         ORDER BY g.is_primary DESC, g.created_at DESC`,
        [userId]
      );

      return res.rows.map((row) => ({
        id: row.id,
        userId: row.user_id,
        goalType: row.goal_type,
        targetMetricTypeCode: row.target_metric_type_code,
        isPrimary: row.is_primary,
        status: row.status,
        createdAt: row.created_at.toISOString(),
        updatedAt: row.updated_at.toISOString(),
        currentVersion: row.v_id ? {
          id: row.v_id,
          goalId: row.id,
          userId: row.user_id,
          version: row.version,
          targetValue: Number(row.target_value),
          startingValue: Number(row.starting_value),
          weeklyRate: row.weekly_rate ? Number(row.weekly_rate) : undefined,
          startDate: row.start_date.toISOString ? row.start_date.toISOString().split('T')[0] : String(row.start_date),
          targetDate: row.target_date ? (row.target_date.toISOString ? row.target_date.toISOString().split('T')[0] : String(row.target_date)) : undefined,
          rationale: row.rationale || undefined,
          createdAt: row.v_created_at.toISOString()
        } : undefined
      }));
    });
  }

  public async exportUserData(userId: string): Promise<Record<string, unknown>> {
    return withUserContext(userId, async (client) => {
      const goalsRes = await client.query(`SELECT * FROM goals WHERE user_id = $1 ORDER BY created_at ASC`, [userId]);
      const versionsRes = await client.query(`SELECT * FROM goal_versions WHERE user_id = $1 ORDER BY created_at ASC`, [userId]);
      return {
        goals: goalsRes.rows,
        goalVersions: versionsRes.rows
      };
    });
  }

  public async updateGoalStatus(userId: string, goalId: string, status: string): Promise<boolean> {
    return withUserContext(userId, async (client) => {
      const res = await client.query(
        `UPDATE goals SET status = $1, updated_at = NOW() WHERE id = $2 AND user_id = $3`,
        [status, goalId, userId]
      );
      return (res.rowCount ?? 0) > 0;
    });
  }

  public async purgeUserData(userId: string): Promise<void> {
    return withUserContext(userId, async (client) => {
      await client.query(`DELETE FROM goal_versions WHERE user_id = $1`, [userId]);
      await client.query(`DELETE FROM goals WHERE user_id = $1`, [userId]);
    });
  }
}
