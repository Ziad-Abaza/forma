import { Pool } from 'pg';
import argon2 from 'argon2';
import dotenv from 'dotenv';
import path from 'path';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const dbUrl = process.env.DATABASE_URL_MIGRATIONS || 'postgresql://postgres:postgrespassword@localhost:5432/forma_dev';

async function hashPassword(password: string): Promise<string> {
  return argon2.hash(password, {
    type: argon2.argon2id,
    memoryCost: 65536,
    timeCost: 3,
    parallelism: 4
  });
}

async function main() {
  const pool = new Pool({ connectionString: dbUrl });
  const client = await pool.connect();

  try {
    console.log('--- Starting Database Reset & Targeted Seeding ---');

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

    // 2. Identity, Authentication & Consent
    console.log('Inserting user: ziadabaza12345@gmail.com...');
    const userRes = await client.query(`
      INSERT INTO users (
        id, email, role, locale, numeral_system, status, email_verified, created_at, updated_at
      ) VALUES (
        gen_random_uuid(),
        'ziadabaza12345@gmail.com',
        'user',
        'ar',
        'western',
        'active',
        true,
        '2026-07-15 00:00:00+00',
        '2026-07-15 00:00:00+00'
      ) RETURNING id
    `);
    const userId = userRes.rows[0].id;
    console.log(`User created with ID: ${userId}`);

    // Create user credentials with a known password ('Password123!')
    const pwdHash = await hashPassword('Password5536');
    await client.query(`
      INSERT INTO credentials (user_id, password_hash, created_at, updated_at)
      VALUES ($1, $2, '2026-07-15 00:00:00+00', '2026-07-15 00:00:00+00')
    `, [userId, pwdHash]);

    // Create default consent
    await client.query(`
      INSERT INTO consents (user_id, policy_type, version, granted, granted_at)
      VALUES ($1, 'privacy_policy', '1.0', true, '2026-07-15 00:00:00+00')
    `, [userId]);

    // 3. Profiles
    console.log('Inserting profile...');
    await client.query(`
      INSERT INTO profiles (
        user_id,
        date_of_birth,
        sex_for_calculation,
        height_cm,
        activity_level,
        experience_level,
        constraints,
        preferences,
        created_at,
        updated_at
      ) VALUES (
        $1,
        '2002-07-15',
        'male',
        180.00,
        'sedentary',
        'advanced',
        ARRAY['night_shift_worker', 'extended_screen_time'],
        '{"fasting_window": "17:00-01:00", "family_dinner": "17:00"}'::jsonb,
        '2026-07-15 00:00:00+00',
        '2026-07-15 00:00:00+00'
      )
    `, [userId]);

    // Profile History
    await client.query(`
      INSERT INTO profile_history (
        user_id, attribute_name, old_value, new_value, effective_from, actor
      ) VALUES (
        $1,
        'initial_profile',
        null,
        '{"height_cm": 180.00, "date_of_birth": "2002-07-15", "sex": "male", "activity_level": "sedentary"}'::jsonb,
        '2026-07-15 00:00:00+00',
        'system'
      )
    `, [userId]);

    // 4. Measurements & Append-Only Observations
    console.log('Inserting provenance and observation (weight 85.00 kg)...');
    const provRes = await client.query(`
      INSERT INTO provenance_records (
        user_id, origin_type, epistemic_class, actor, method_version,
        confidence_score, review_state, observed_at, recorded_at, reviewed_at
      ) VALUES (
        $1,
        'manual',
        'direct_measurement',
        'user',
        '1.0',
        1.000,
        'confirmed',
        '2026-07-15 00:00:00+00',
        '2026-07-15 00:00:00+00',
        '2026-07-15 00:00:00+00'
      ) RETURNING id
    `, [userId]);
    const provenanceId = provRes.rows[0].id;

    const obsRes = await client.query(`
      INSERT INTO observations (
        user_id,
        type_code,
        canonical_value,
        canonical_unit,
        original_value,
        original_unit,
        input_precision,
        observed_at,
        recorded_at,
        time_zone,
        provenance_id,
        quality_flags,
        status
      ) VALUES (
        $1,
        'weight',
        85.0000,
        'kg',
        85.0000,
        'kg',
        2,
        '2026-07-15 00:00:00+00',
        '2026-07-15 00:00:00+00',
        'UTC',
        $2,
        '{}',
        'active'
      ) RETURNING id
    `, [userId, provenanceId]);
    const observationId = obsRes.rows[0].id;
    console.log(`Observation created with ID: ${observationId}`);

    // 5. Goals & Analytical Projections
    console.log('Inserting goal and goal_version (weight loss to 70 kg)...');
    const goalRes = await client.query(`
      INSERT INTO goals (
        user_id, goal_type, target_metric_type_code, is_primary, status, created_at, updated_at
      ) VALUES (
        $1,
        'weight_loss',
        'weight',
        true,
        'active',
        '2026-07-15 00:00:00+00',
        '2026-07-15 00:00:00+00'
      ) RETURNING id
    `, [userId]);
    const goalId = goalRes.rows[0].id;

    await client.query(`
      INSERT INTO goal_versions (
        goal_id,
        user_id,
        version,
        target_value,
        starting_value,
        weekly_rate,
        start_date,
        target_date,
        rationale,
        created_at
      ) VALUES (
        $1,
        $2,
        1,
        70.0000,
        85.0000,
        -1.2500,
        '2026-07-15',
        '2026-10-15',
        'Rapid deficit execution to hit 70kg threshold. Muscle memory leveraged for lean mass retention.',
        '2026-07-15 00:00:00+00'
      )
    `, [goalId, userId]);

    // 6. Conversational Assistant Memories
    console.log('Inserting assistant memories...');
    const memories = [
      {
        category: 'constraint',
        key: 'compliance_rules',
        value: 'Zero compromise protocol. Rejects cheat meals and skipped workouts entirely.'
      },
      {
        category: 'routine',
        key: 'fasting_schedule',
        value: 'Intermittent fasting adjusted to 17:00 - 01:00 to align with 17:00 family dinner and late-night work.'
      },
      {
        category: 'preference',
        key: 'training_parameters',
        value: 'Prefers PPL or Upper/Lower splits. Incorporates specific intensity techniques: lateral deltoid supersets and bicep drop sets.'
      },
      {
        category: 'fact',
        key: 'professional_lifestyle',
        value: 'Full-Stack Software Engineer (Laravel/Node.js/Redis) with high cognitive load and extremely low baseline physical movement.'
      }
    ];

    for (const mem of memories) {
      await client.query(`
        INSERT INTO assistant_memories (
          user_id, category, key, value, confidence, source, is_active, created_at, updated_at
        ) VALUES (
          $1, $2, $3, $4, 1.0, 'user_specified', true, '2026-07-15 00:00:00+00', '2026-07-15 00:00:00+00'
        )
      `, [userId, mem.category, mem.key, mem.value]);
    }

    // 7. Audit Log of database initialization
    await client.query(`
      INSERT INTO audit_logs (
        user_id, actor_type, action, entity_type, entity_id, correlation_id, status, metadata, created_at
      ) VALUES (
        $1::uuid, 'system', 'SEED_CUSTOM_DATA', 'user', $2, 'init-seed-custom', 'SUCCESS',
        '{"note": "Initialized profile, baseline weight observation, goal, and memories"}'::jsonb,
        NOW()
      )
    `, [userId, userId]);

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
    console.log(`Email: ziad.hassan.engineer@system.local`);
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Failed to reset and seed database:', err);
    throw err;
  } finally {
    client.release();
    await pool.end();
  }
}

main().catch(() => process.exit(1));
