import type { PoolClient } from 'pg';

export interface UserRecord {
  id: string;
  email: string;
  role: string;
  locale: string;
  numeral_system: string;
  status: string;
  email_verified: boolean;
  created_at: Date;
  updated_at: Date;
}

export interface SessionRecord {
  id: string;
  user_id: string;
  device_info: Record<string, unknown>;
  refresh_token_hash: string;
  family_id: string;
  is_revoked: boolean;
  expires_at: Date;
  created_at: Date;
  updated_at: Date;
}

export interface ConsentRecord {
  id: string;
  user_id: string;
  policy_type: string;
  version: string;
  granted: boolean;
  granted_at: Date;
  withdrawn_at: Date | null;
}

export class IdentityRepository {
  static async createUser(
    client: PoolClient,
    data: { email: string; role?: string; locale?: string; numeralSystem?: string }
  ): Promise<UserRecord> {
    const res = await client.query(
      `INSERT INTO users (email, role, locale, numeral_system)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [data.email, data.role || 'user', data.locale || 'en', data.numeralSystem || 'western']
    );
    return res.rows[0] as UserRecord;
  }

  static async findUserByEmail(client: PoolClient, email: string): Promise<UserRecord | null> {
    const res = await client.query('SELECT * FROM users WHERE email = $1', [email]);
    return (res.rows[0] as UserRecord) || null;
  }

  static async findUserById(client: PoolClient, id: string): Promise<UserRecord | null> {
    const res = await client.query('SELECT * FROM users WHERE id = $1', [id]);
    return (res.rows[0] as UserRecord) || null;
  }

  static async updateUserPreferences(
    client: PoolClient,
    userId: string,
    preferences: { locale?: string | undefined; numeralSystem?: string | undefined }
  ): Promise<UserRecord> {
    const fields: string[] = ['updated_at = NOW()'];
    const params: unknown[] = [userId];
    let idx = 2;

    if (preferences.locale) {
      fields.push(`locale = $${idx++}`);
      params.push(preferences.locale);
    }
    if (preferences.numeralSystem) {
      fields.push(`numeral_system = $${idx++}`);
      params.push(preferences.numeralSystem);
    }

    const res = await client.query(
      `UPDATE users SET ${fields.join(', ')} WHERE id = $1 RETURNING *`,
      params
    );
    return res.rows[0] as UserRecord;
  }

  static async createCredentials(
    client: PoolClient,
    userId: string,
    passwordHash: string
  ): Promise<void> {
    await client.query(
      `INSERT INTO credentials (user_id, password_hash)
       VALUES ($1, $2)`,
      [userId, passwordHash]
    );
  }

  static async findPasswordHashByUserId(client: PoolClient, userId: string): Promise<string | null> {
    const res = await client.query('SELECT password_hash FROM credentials WHERE user_id = $1', [userId]);
    return res.rows[0]?.password_hash || null;
  }

  static async createSession(
    client: PoolClient,
    data: {
      userId: string;
      deviceInfo?: Record<string, unknown> | undefined;
      refreshTokenHash: string;
      familyId: string;
      expiresAt: Date;
    }
  ): Promise<SessionRecord> {
    const res = await client.query(
      `INSERT INTO sessions (user_id, device_info, refresh_token_hash, family_id, expires_at)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [data.userId, JSON.stringify(data.deviceInfo || {}), data.refreshTokenHash, data.familyId, data.expiresAt]
    );
    return res.rows[0] as SessionRecord;
  }

  static async findSessionByTokenHash(client: PoolClient, tokenHash: string): Promise<SessionRecord | null> {
    const res = await client.query('SELECT * FROM sessions WHERE refresh_token_hash = $1', [tokenHash]);
    return (res.rows[0] as SessionRecord) || null;
  }

  static async revokeSession(client: PoolClient, sessionId: string): Promise<void> {
    await client.query('UPDATE sessions SET is_revoked = true, updated_at = NOW() WHERE id = $1', [sessionId]);
  }

  static async revokeSessionFamily(client: PoolClient, userId: string, familyId: string): Promise<number> {
    const res = await client.query(
      'UPDATE sessions SET is_revoked = true, updated_at = NOW() WHERE user_id = $1 AND family_id = $2',
      [userId, familyId]
    );
    return res.rowCount || 0;
  }

  static async listSessionsForUser(client: PoolClient, userId: string): Promise<SessionRecord[]> {
    const res = await client.query(
      `SELECT id, user_id, device_info, family_id, is_revoked, expires_at, created_at, updated_at
       FROM sessions WHERE user_id = $1 ORDER BY created_at DESC`,
      [userId]
    );
    return res.rows as SessionRecord[];
  }

  static async revokeSessionForUser(client: PoolClient, userId: string, sessionId: string): Promise<boolean> {
    const res = await client.query(
      'UPDATE sessions SET is_revoked = true, updated_at = NOW() WHERE id = $1 AND user_id = $2',
      [sessionId, userId]
    );
    return (res.rowCount || 0) > 0;
  }

  static async revokeAllSessionsForUser(client: PoolClient, userId: string): Promise<number> {
    const res = await client.query(
      'UPDATE sessions SET is_revoked = true, updated_at = NOW() WHERE user_id = $1 AND is_revoked = false',
      [userId]
    );
    return res.rowCount || 0;
  }

  static async updatePasswordHash(client: PoolClient, userId: string, passwordHash: string): Promise<void> {
    await client.query(
      'UPDATE credentials SET password_hash = $1, updated_at = NOW() WHERE user_id = $2',
      [passwordHash, userId]
    );
  }

  static async listConsents(client: PoolClient, userId: string): Promise<ConsentRecord[]> {
    const res = await client.query(
      `SELECT id, user_id, policy_type, version, granted, granted_at, withdrawn_at
       FROM consents WHERE user_id = $1 ORDER BY granted_at DESC`,
      [userId]
    );
    return res.rows as ConsentRecord[];
  }

  static async withdrawLatestConsent(client: PoolClient, userId: string, policyType: string): Promise<boolean> {
    const res = await client.query(
      `UPDATE consents SET withdrawn_at = NOW()
       WHERE id = (
         SELECT id FROM consents
         WHERE user_id = $1 AND policy_type = $2 AND granted = true AND withdrawn_at IS NULL
         ORDER BY granted_at DESC LIMIT 1
       )`,
      [userId, policyType]
    );
    return (res.rowCount || 0) > 0;
  }

  static async hasActiveConsent(client: PoolClient, userId: string, policyType: string): Promise<boolean> {
    const res = await client.query(
      `SELECT EXISTS(
         SELECT 1 FROM consents
         WHERE user_id = $1 AND policy_type = $2 AND granted = true AND withdrawn_at IS NULL
       ) AS has`,
      [userId, policyType]
    );
    return res.rows[0]?.has === true;
  }

  static async createConsent(
    client: PoolClient,
    data: { userId: string; policyType: string; version: string; granted: boolean }
  ): Promise<void> {
    await client.query(
      `INSERT INTO consents (user_id, policy_type, version, granted)
       VALUES ($1, $2, $3, $4)`,
      [data.userId, data.policyType, data.version, data.granted]
    );
  }

  static async createInitialProfile(
    client: PoolClient,
    data: {
      userId: string;
      dateOfBirth: string;
      heightCm: number;
      sexForCalculation: string;
    }
  ): Promise<void> {
    await client.query(
      `INSERT INTO profiles (user_id, date_of_birth, height_cm, sex_for_calculation)
       VALUES ($1, $2, $3, $4)`,
      [data.userId, data.dateOfBirth, data.heightCm, data.sexForCalculation]
    );

    // Also record initial profile attributes in history for reproducible lineage
    await client.query(
      `INSERT INTO profile_history (user_id, attribute_name, new_value, actor)
       VALUES
         ($1, 'height_cm', $2, 'user_onboarding'),
         ($1, 'sex_for_calculation', $3, 'user_onboarding')`,
      [data.userId, JSON.stringify(data.heightCm), JSON.stringify(data.sexForCalculation)]
    );
  }
}
