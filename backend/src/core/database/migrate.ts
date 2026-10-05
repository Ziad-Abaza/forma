import fs from 'fs';
import path from 'path';
import { Pool } from 'pg';
import { closePool } from './index.js';

const APP_ROLE_PASSWORD_PLACEHOLDER = '__FORMA_APP_DB_PASSWORD__';

function getMigrationPool(): Pool {
  const adminUrl = process.env['DATABASE_URL_MIGRATIONS'];
  if (!adminUrl || adminUrl.trim().length === 0) {
    throw new Error(
      'DATABASE_URL_MIGRATIONS is required to run migrations (schema-owner/superuser connection string). No fallback exists.'
    );
  }
  return new Pool({ connectionString: adminUrl });
}

/**
 * Resolves env-parameterized placeholders in migration SQL.
 * Migrations must never embed credential literals; secrets are injected at apply time.
 */
function resolveMigrationSql(fileName: string, rawSql: string): string {
  if (!rawSql.includes(APP_ROLE_PASSWORD_PLACEHOLDER)) {
    return rawSql;
  }
  const appRolePassword = process.env['FORMA_APP_DB_PASSWORD'];
  if (!appRolePassword) {
    throw new Error(
      `Migration ${fileName} requires FORMA_APP_DB_PASSWORD to provision the application role. Refusing to apply with a missing password.`
    );
  }
  return rawSql.split(APP_ROLE_PASSWORD_PLACEHOLDER).join(appRolePassword.replaceAll("'", "''"));
}

/** Fixed advisory-lock key that serializes all migration runners for this app. */
export const MIGRATION_ADVISORY_LOCK_KEY = 987654321;

export async function runMigrations(): Promise<void> {
  const pool = getMigrationPool();
  const client = await pool.connect();

  try {
    // Acquire session-level advisory lock to serialize concurrent test migration runners
    await client.query(`SELECT pg_advisory_lock(${MIGRATION_ADVISORY_LOCK_KEY})`);

    console.log('Beginning database migrations...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version VARCHAR(255) PRIMARY KEY,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    `);

    const srcDir = path.resolve(__dirname, '../../../src/core/database/migrations');
    const altSrcDir = path.resolve(process.cwd(), 'src/core/database/migrations');
    const localDir = path.join(__dirname, 'migrations');
    const migrationsDir = fs.existsSync(srcDir)
      ? srcDir
      : fs.existsSync(altSrcDir)
      ? altSrcDir
      : localDir;
    const files = fs.readdirSync(migrationsDir)
      .filter(f => f.endsWith('.sql'))
      .sort();

    for (const file of files) {
      const res = await client.query('SELECT 1 FROM schema_migrations WHERE version = $1', [file]);
      if (res.rowCount && res.rowCount > 0) {
        console.log(`Migration ${file} already applied.`);
        continue;
      }

      console.log(`Applying migration: ${file}...`);
      const sql = resolveMigrationSql(file, fs.readFileSync(path.join(migrationsDir, file), 'utf8'));

      await client.query('BEGIN');
      await client.query(sql);
      await client.query('INSERT INTO schema_migrations (version) VALUES ($1)', [file]);
      await client.query('COMMIT');
      console.log(`Migration ${file} applied successfully.`);
    }

    console.log('All migrations applied successfully.');
  } catch (error) {
    try {
      await client.query('ROLLBACK');
    } catch {}
    console.error('Migration failed:', error);
    throw error;
  } finally {
    try {
      await client.query(`SELECT pg_advisory_unlock(${MIGRATION_ADVISORY_LOCK_KEY})`);
    } catch {}
    client.release();
    await pool.end();
  }
}

// Allow direct CLI execution
if (process.argv[1] && process.argv[1].endsWith('migrate.ts')) {
  runMigrations()
    .then(() => closePool())
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}
