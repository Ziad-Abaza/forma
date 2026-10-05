import { Pool } from 'pg';
import crypto from 'crypto';
import dotenv from 'dotenv';
import path from 'path';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

/**
 * Local-development reset & seed script.
 *
 * Safety contract:
 *  - Requires DATABASE_URL_MIGRATIONS (schema-owner/superuser DSN). No fallback.
 *  - Refuses to run when NODE_ENV=production.
 *  - Requires FORMA_SEED_CONFIRM=RESET_LOCAL_DB so it can never fire accidentally.
 *  - Seeds only clearly synthetic data (@forma.test domain, generated password
 *    printed once to stdout, never committed).
 */

const SEED_CONFIRM_VALUE = 'RESET_LOCAL_DB';
const SEED_EMAIL = 'dev.user@forma.test';

function assertSeedAllowed(): string {
  if (process.env.NODE_ENV === 'production') {
    throw new Error('reset_and_seed.ts refuses to run when NODE_ENV=production.');
  }
  if (process.env.FORMA_SEED_CONFIRM !== SEED_CONFIRM_VALUE) {
    throw new Error(
      `Destructive seed requires FORMA_SEED_CONFIRM=${SEED_CONFIRM_VALUE} in the environment.`
    );
  }
  const dbUrl = process.env.DATABASE_URL_MIGRATIONS;
  if (!dbUrl || dbUrl.trim().length === 0) {
    throw new Error('DATABASE_URL_MIGRATIONS is required. No fallback exists.');
  }
  return dbUrl;
}

async function main() {
  const dbUrl = assertSeedAllowed();
  const generatedPassword = crypto.randomBytes(18).toString('base64url');

  const { hashPassword } = await import('../src/core/security/index.js');

  const pool = new Pool({ connectionString: dbUrl });
  const client = await pool.connect();

  try {
    console.log('--- Starting Database Reset & Synthetic Seeding ---');

    await client.query('BEGIN');
    await client.query("SET LOCAL app.allow_purge = 'true'");
    await client.query("SET LOCAL app.is_system = 'true'");

    // 1. Clear all demo / seed data from domain tables (preserving measurement_types & schema_migrations)
    console.log('Clearing existing records...');
    const tablesToPurge = [
      'audit_logs',
      'sync_dedup_records',
      'import_batches',
      'integration_connections',
      'extraction_drafts',
      'media_artifacts',
      'action_proposals',
      'conversation_messages',
      'conversations',
      'assistant_memories',
      'user_ai_credentials',
      'ai_traces',
      'anomaly_flags',
      'metric_rollups',
      'health_snapshots',
      'goal_versions',
      'goals',
      'observations',
      'provenance_records',
      'profile_history',
      'profiles',
      'consents',
      'sessions',
      'credentials',
      'users'
    ];

    for (const table of tablesToPurge) {
      await client.query(`DELETE FROM ${table}`);
    }
    console.log('All user and operational tables cleared successfully.');

    // 2. Identity, Authentication & Consent (synthetic identity only)
    console.log(`Inserting synthetic user: ${SEED_EMAIL}...`);
    const userRes = await client.query(
      `
      INSERT INTO users (
        id, email, role, locale, numeral_system, status, email_verified, created_at, updated_at
      ) VALUES (
        gen_random_uuid(), $1, 'user', 'en', 'western', 'active', true, NOW(), NOW()
      ) RETURNING id
    `,
      [SEED_EMAIL]
    );
    const userId = userRes.rows[0].id;
    console.log(`User created with ID: ${userId}`);

    const pwdHash = await hashPassword(generatedPassword);
    await client.query(
      `
      INSERT INTO credentials (user_id, password_hash, created_at, updated_at)
      VALUES ($1, $2, NOW(), NOW())
    `,
      [userId, pwdHash]
    );

    // Contract-correct consent records (policy types per identity/service.ts)
    const consents = [
      'terms_of_service',
      'health_data_processing',
      'ai_third_party_processing'
    ];
    for (const policyType of consents) {
      await client.query(
        `
        INSERT INTO consents (user_id, policy_type, version, granted, granted_at)
        VALUES ($1, $2, '1.0', true, NOW())
      `,
        [userId, policyType]
      );
    }

    // 3. Profiles (synthetic)
    console.log('Inserting synthetic profile...');
    await client.query(
      `
      INSERT INTO profiles (
        user_id, date_of_birth, sex_for_calculation, height_cm,
        activity_level, experience_level, constraints, preferences,
        created_at, updated_at
      ) VALUES (
        $1, '1990-01-01', 'male', 175.00, 'moderately_active', 'beginner',
        '{}', '{}'::jsonb, NOW(), NOW()
      )
    `,
      [userId]
    );

    await client.query(
      `
      INSERT INTO profile_history (
        user_id, attribute_name, old_value, new_value, effective_from, actor
      ) VALUES (
        $1, 'initial_profile', null,
        '{"height_cm": 175.00, "date_of_birth": "1990-01-01", "sex": "male", "activity_level": "moderately_active"}'::jsonb,
        NOW(), 'system'
      )
    `,
      [userId]
    );

    // 4. Measurements & Append-Only Observations (contract-correct provenance enums)
    console.log('Inserting provenance and synthetic observation (weight 80.00 kg)...');
    const provRes = await client.query(
      `
      INSERT INTO provenance_records (
        user_id, origin_type, epistemic_class, actor, method_version,
        confidence_score, review_state, observed_at, recorded_at, reviewed_at
      ) VALUES (
        $1, 'manual_entry', 'measured', 'user', '1.0', 1.000,
        'user_reviewed', NOW(), NOW(), NOW()
      ) RETURNING id
    `,
      [userId]
    );
    const provenanceId = provRes.rows[0].id;

    const obsRes = await client.query(
      `
      INSERT INTO observations (
        user_id, type_code, canonical_value, canonical_unit,
        original_value, original_unit, input_precision,
        observed_at, recorded_at, time_zone, provenance_id, quality_flags, status
      ) VALUES (
        $1, 'weight', 80.0000, 'kg', 80.0000, 'kg', 2,
        NOW(), NOW(), 'UTC', $2, '{}', 'active'
      ) RETURNING id
    `,
      [userId, provenanceId]
    );
    const observationId = obsRes.rows[0].id;
    console.log(`Observation created with ID: ${observationId}`);

    // 5. Goals & Analytical Projections (within engine safe-rate bounds)
    console.log('Inserting goal and goal_version (synthetic weight loss to 75 kg)...');
    const goalRes = await client.query(
      `
      INSERT INTO goals (
        user_id, goal_type, target_metric_type_code, is_primary, status, created_at, updated_at
      ) VALUES (
        $1, 'weight_loss', 'weight', true, 'active', NOW(), NOW()
      ) RETURNING id
    `,
      [userId]
    );
    const goalId = goalRes.rows[0].id;

    await client.query(
      `
      INSERT INTO goal_versions (
        goal_id, user_id, version, target_value, starting_value,
        weekly_rate, start_date, target_date, rationale, created_at
      ) VALUES (
        $1, $2, 1, 75.0000, 80.0000, -0.5000,
        CURRENT_DATE, CURRENT_DATE + INTERVAL '10 weeks',
        'Synthetic seed goal within safe-rate guardrails.', NOW()
      )
    `,
      [goalId, userId]
    );

    // 6. Synthetic assistant memories
    console.log('Inserting synthetic assistant memories...');
    const memories = [
      {
        category: 'preference',
        key: 'training_parameters',
        value: 'Prefers standard beginner full-body routines. Synthetic seed value.'
      },
      {
        category: 'routine',
        key: 'meal_timing',
        value: 'Synthetic seed routine: regular meal timing, no fasting window.'
      }
    ];

    for (const mem of memories) {
      await client.query(
        `
        INSERT INTO assistant_memories (
          user_id, category, key, value, confidence, source, is_active, created_at, updated_at
        ) VALUES ($1, $2, $3, $4, 1.0, 'user_specified', true, NOW(), NOW())
      `,
        [userId, mem.category, mem.key, mem.value]
      );
    }

    // 7. Audit Log of database initialization
    await client.query(
      `
      INSERT INTO audit_logs (
        user_id, actor_type, action, entity_type, entity_id, correlation_id, status, metadata, created_at
      ) VALUES (
        $1::uuid, 'system', 'SEED_SYNTHETIC_DATA', 'user', $2, 'init-seed-synthetic', 'SUCCESS',
        '{"note": "Initialized synthetic profile, baseline observation, goal, and memories"}'::jsonb,
        NOW()
      )
    `,
      [userId, userId]
    );

    await client.query('COMMIT');
    console.log('Database transaction successfully committed.');

    // 8. Reconcile health snapshot for user
    console.log('Generating initial health snapshot...');
    const { SnapshotEngine } = await import('../src/modules/analytics/snapshot.js');
    const engine = new SnapshotEngine();
    const snapshot = await engine.getOrRefreshSnapshot(userId);
    console.log('Health snapshot computed and saved successfully. Watermark:', snapshot.sourceDataWatermark);

    console.log('\n=== Database reset & seeding finished successfully ===');
    console.log(`User ID: ${userId}`);
    console.log(`Email: ${SEED_EMAIL}`);
    console.log(`Generated password (shown once, not stored in source): ${generatedPassword}`);
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Failed to reset and seed database:', err);
    throw err;
  } finally {
    client.release();
    await pool.end();
    const { closePool } = await import('../src/core/database/index.js');
    await closePool();
  }
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
