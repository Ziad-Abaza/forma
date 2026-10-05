import { Pool, type PoolClient } from 'pg';
import { getDatabaseUrl } from '../../config/index.js';

let poolInstance: Pool | null = null;

export function getPool(): Pool {
  if (!poolInstance) {
    poolInstance = new Pool({
      connectionString: getDatabaseUrl(),
      max: 20,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 5000,
    });
  }
  return poolInstance;
}

export async function closePool(): Promise<void> {
  if (poolInstance) {
    await poolInstance.end();
    poolInstance = null;
  }
}

/**
 * Executes a callback within an isolated PostgreSQL transaction bound to the authenticated user's ID.
 * Sets `app.current_user_id` so that Row-Level Security policies are strictly enforced by the database.
 */
export async function withUserContext<T>(
  userId: string,
  fn: (client: PoolClient) => Promise<T>
): Promise<T> {
  const pool = getPool();
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query("SELECT set_config('app.current_user_id', $1, true)", [userId]);
    await client.query("SELECT set_config('app.is_system', 'false', true)");
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch {
      // Ignore if transaction already ended
    }
    throw error;
  } finally {
    client.release();
  }
}

/**
 * Executes a callback within a system-level PostgreSQL transaction.
 * Only used for migrations, background maintenance, and initial user registration before ID exists.
 */
export async function withSystemContext<T>(
  fn: (client: PoolClient) => Promise<T>
): Promise<T> {
  const pool = getPool();
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query("SELECT set_config('app.is_system', 'true', true)");
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch {
      // Ignore if transaction already ended
    }
    throw error;
  } finally {
    client.release();
  }
}

/**
 * Executes an account privacy purge transaction with explicit allow_purge flag.
 * Required to reconcile append-only fact immutability with GDPR/privacy deletion contracts.
 */
export async function withPurgeContext<T>(
  userId: string,
  fn: (client: PoolClient) => Promise<T>
): Promise<T> {
  const pool = getPool();
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query("SELECT set_config('app.current_user_id', $1, true)", [userId]);
    await client.query("SELECT set_config('app.allow_purge', 'true', true)");
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch {
      // Ignore if transaction already ended
    }
    throw error;
  } finally {
    client.release();
  }
}
