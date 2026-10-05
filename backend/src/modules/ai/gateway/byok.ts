import crypto from 'crypto';
import { withUserContext } from '../../../core/database/index.js';

export interface UserAICredential {
  id: string;
  userId: string;
  provider: string;
  keyFingerprint: string;
  isActive: boolean;
  createdAt: Date;
}

export class BYOKService {
  private readonly algorithm = 'aes-256-gcm';
  private readonly masterKey: Buffer;
  private readonly allowedProviders = new Set(['google', 'openai', 'anthropic', 'secondary']);

  constructor(_pool?: any, masterKeyHex?: string) {
    const secret =
      masterKeyHex ||
      process.env.ENCRYPTION_MASTER_KEY ||
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    this.masterKey = Buffer.from(secret, 'hex');
  }

  public isProviderAllowed(provider: string): boolean {
    return this.allowedProviders.has(provider.toLowerCase());
  }

  public encryptKey(plainKey: string): { encrypted: string; fingerprint: string } {
    if (!plainKey || plainKey.length < 8) {
      throw new Error('API key too short or empty');
    }
    const iv = crypto.randomBytes(12);
    const cipher = crypto.createCipheriv(this.algorithm, this.masterKey, iv);
    let encrypted = cipher.update(plainKey, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    const authTag = cipher.getAuthTag().toString('hex');
    const payload = `${iv.toString('hex')}:${authTag}:${encrypted}`;

    const fingerprint = `...${plainKey.slice(-4)}`;
    return { encrypted: payload, fingerprint };
  }

  public decryptKey(encryptedPayload: string): string {
    const parts = encryptedPayload.split(':');
    if (parts.length !== 3) {
      throw new Error('Invalid encrypted payload format');
    }
    const [ivHex, authTagHex, encryptedText] = parts;
    const iv = Buffer.from(ivHex!, 'hex');
    const authTag = Buffer.from(authTagHex!, 'hex');
    const decipher = crypto.createDecipheriv(this.algorithm, this.masterKey, iv);
    decipher.setAuthTag(authTag);
    let decrypted = decipher.update(encryptedText!, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    return decrypted;
  }

  public async storeUserKey(
    userId: string,
    provider: string,
    plainKey: string
  ): Promise<UserAICredential> {
    const normalizedProvider = provider.toLowerCase();
    if (!this.isProviderAllowed(normalizedProvider)) {
      throw new Error(`Provider '${provider}' is not in the allowlist`);
    }

    const { encrypted, fingerprint } = this.encryptKey(plainKey);

    return withUserContext(userId, async (client) => {
      const res = await client.query(
        `INSERT INTO user_ai_credentials (user_id, provider, encrypted_key, key_fingerprint)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (user_id, provider)
         DO UPDATE SET encrypted_key = EXCLUDED.encrypted_key,
                       key_fingerprint = EXCLUDED.key_fingerprint,
                       is_active = TRUE,
                       updated_at = NOW()
         RETURNING id, user_id, provider, key_fingerprint, is_active, created_at`,
        [userId, normalizedProvider, encrypted, fingerprint]
      );

      const row = res.rows[0];
      return {
        id: row.id,
        userId: row.user_id,
        provider: row.provider,
        keyFingerprint: row.key_fingerprint,
        isActive: row.is_active,
        createdAt: row.created_at,
      };
    });
  }

  public async resolveUserKey(userId: string, provider: string): Promise<string | undefined> {
    return withUserContext(userId, async (client) => {
      const res = await client.query(
        `SELECT encrypted_key FROM user_ai_credentials
         WHERE user_id = $1 AND provider = $2 AND is_active = TRUE`,
        [userId, provider.toLowerCase()]
      );

      if (res.rows.length === 0) return undefined;
      return this.decryptKey(res.rows[0].encrypted_key);
    });
  }

  public async listUserCredentials(userId: string): Promise<UserAICredential[]> {
    return withUserContext(userId, async (client) => {
      const res = await client.query(
        `SELECT id, user_id, provider, key_fingerprint, is_active, created_at
         FROM user_ai_credentials
         WHERE user_id = $1
         ORDER BY created_at ASC`,
        [userId]
      );

      return res.rows.map((row) => ({
        id: row.id,
        userId: row.user_id,
        provider: row.provider,
        keyFingerprint: row.key_fingerprint,
        isActive: row.is_active,
        createdAt: row.created_at,
      }));
    });
  }

  public async deleteUserKey(userId: string, provider: string): Promise<boolean> {
    return withUserContext(userId, async (client) => {
      const res = await client.query(
        `DELETE FROM user_ai_credentials WHERE user_id = $1 AND provider = $2`,
        [userId, provider.toLowerCase()]
      );
      return (res.rowCount ?? 0) > 0;
    });
  }
}
