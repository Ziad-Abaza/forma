import fs from 'fs';
import path from 'path';
import { Pool } from 'pg';
import { closePool } from './index.js';

function getMigrationPool(): Pool {
  const adminUrl = process.env['DATABASE_URL_MIGRATIONS'] ||
    (process.env['NODE_ENV'] === 'test'
      ? 'postgresql://postgres:postgres@localhost:5432/forma_test'
      : 'postgresql://postgres:postgres@localhost:5432/forma_dev');
  return new Pool({ connectionString: adminUrl });
}

export async function runMigrations(): Promise<void> {
  const pool = getMigrationPool();
  const client = await pool.connect();

  try {
    console.log('Beginning database migrations...');
    await client.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version VARCHAR(255) PRIMARY KEY,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    `);

    const migrationsDir = path.join(__dirname, 'migrations');
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
      const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf8');

      await client.query('BEGIN');
      await client.query(sql);
      await client.query('INSERT INTO schema_migrations (version) VALUES ($1)', [file]);
      await client.query('COMMIT');
      console.log(`Migration ${file} applied successfully.`);
    }

    console.log('All migrations applied successfully.');
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Migration failed:', error);
    throw error;
  } finally {
    client.release();
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
