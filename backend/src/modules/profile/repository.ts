import type { PoolClient } from 'pg';
import type { ProfileResponse, ProfileHistoryEntry } from './contracts.js';

export class ProfileRepository {
  static async getProfileByUserId(client: PoolClient, userId: string): Promise<ProfileResponse | null> {
    const res = await client.query('SELECT * FROM profiles WHERE user_id = $1', [userId]);
    if (!res.rows[0]) return null;
    const r = res.rows[0];
    return {
      userId: r.user_id,
      dateOfBirth: r.date_of_birth instanceof Date ? r.date_of_birth.toISOString().split('T')[0]! : String(r.date_of_birth),
      sexForCalculation: r.sex_for_calculation,
      heightCm: Number(r.height_cm),
      activityLevel: r.activity_level,
      experienceLevel: r.experience_level,
      constraints: r.constraints || [],
      preferences: r.preferences || {},
      createdAt: r.created_at,
      updatedAt: r.updated_at
    };
  }

  static async updateProfile(
    client: PoolClient,
    userId: string,
    updates: {
      heightCm?: number | undefined;
      sexForCalculation?: string | undefined;
      activityLevel?: string | undefined;
      experienceLevel?: string | undefined;
      constraints?: string[] | undefined;
      preferences?: Record<string, unknown> | undefined;
    }
  ): Promise<ProfileResponse> {
    const fields: string[] = ['updated_at = NOW()'];
    const params: unknown[] = [userId];
    let idx = 2;

    if (updates.heightCm !== undefined) {
      fields.push(`height_cm = $${idx++}`);
      params.push(updates.heightCm);
    }
    if (updates.sexForCalculation !== undefined) {
      fields.push(`sex_for_calculation = $${idx++}`);
      params.push(updates.sexForCalculation);
    }
    if (updates.activityLevel !== undefined) {
      fields.push(`activity_level = $${idx++}`);
      params.push(updates.activityLevel);
    }
    if (updates.experienceLevel !== undefined) {
      fields.push(`experience_level = $${idx++}`);
      params.push(updates.experienceLevel);
    }
    if (updates.constraints !== undefined) {
      fields.push(`constraints = $${idx++}`);
      params.push(updates.constraints);
    }
    if (updates.preferences !== undefined) {
      fields.push(`preferences = $${idx++}`);
      params.push(JSON.stringify(updates.preferences));
    }

    const sql = `
      UPDATE profiles
      SET ${fields.join(', ')}
      WHERE user_id = $1
      RETURNING *
    `;
    const res = await client.query(sql, params);
    const r = res.rows[0];
    return {
      userId: r.user_id,
      dateOfBirth: r.date_of_birth instanceof Date ? r.date_of_birth.toISOString().split('T')[0]! : String(r.date_of_birth),
      sexForCalculation: r.sex_for_calculation,
      heightCm: Number(r.height_cm),
      activityLevel: r.activity_level,
      experienceLevel: r.experience_level,
      constraints: r.constraints || [],
      preferences: r.preferences || {},
      createdAt: r.created_at,
      updatedAt: r.updated_at
    };
  }

  static async recordAttributeHistory(
    client: PoolClient,
    userId: string,
    attributeName: string,
    oldValue: unknown,
    newValue: unknown,
    actor: string
  ): Promise<void> {
    await client.query(
      `INSERT INTO profile_history (user_id, attribute_name, old_value, new_value, actor)
       VALUES ($1, $2, $3, $4, $5)`,
      [userId, attributeName, JSON.stringify(oldValue), JSON.stringify(newValue), actor]
    );
  }

  static async getProfileHistory(
    client: PoolClient,
    userId: string,
    attributeName?: string
  ): Promise<ProfileHistoryEntry[]> {
    let sql = 'SELECT * FROM profile_history WHERE user_id = $1';
    const params: unknown[] = [userId];

    if (attributeName) {
      sql += ' AND attribute_name = $2';
      params.push(attributeName);
    }
    sql += ' ORDER BY effective_from DESC';

    const res = await client.query(sql, params);
    return res.rows.map(r => ({
      id: r.id,
      userId: r.user_id,
      attributeName: r.attribute_name,
      oldValue: r.old_value,
      newValue: r.new_value,
      effectiveFrom: r.effective_from,
      actor: r.actor
    }));
  }
}
