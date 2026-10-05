-- Forma Database Migration 001: Phase 1 Initial Schema & RLS Policies

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. Users Table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    role VARCHAR(32) NOT NULL DEFAULT 'user',
    locale VARCHAR(10) NOT NULL DEFAULT 'en',
    numeral_system VARCHAR(20) NOT NULL DEFAULT 'western',
    status VARCHAR(32) NOT NULL DEFAULT 'active',
    email_verified BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Credentials Table
CREATE TABLE IF NOT EXISTS credentials (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Sessions Table (Short-lived access + rotating refresh tokens with reuse detection)
CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_info JSONB NOT NULL DEFAULT '{}'::jsonb,
    refresh_token_hash VARCHAR(255) NOT NULL,
    family_id UUID NOT NULL,
    is_revoked BOOLEAN NOT NULL DEFAULT false,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_sessions_user_family ON sessions(user_id, family_id);

-- 4. Consents Table
CREATE TABLE IF NOT EXISTS consents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    policy_type VARCHAR(64) NOT NULL,
    version VARCHAR(32) NOT NULL,
    granted BOOLEAN NOT NULL DEFAULT true,
    granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    withdrawn_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_consents_user_policy ON consents(user_id, policy_type);

-- 5. Profiles Table (Minimal, calculation-relevant core attributes)
CREATE TABLE IF NOT EXISTS profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    date_of_birth DATE NOT NULL,
    sex_for_calculation VARCHAR(32) NOT NULL DEFAULT 'unspecified',
    height_cm NUMERIC(5, 2) NOT NULL,
    activity_level VARCHAR(32) NOT NULL DEFAULT 'sedentary',
    experience_level VARCHAR(32) NOT NULL DEFAULT 'beginner',
    constraints TEXT[] NOT NULL DEFAULT '{}',
    preferences JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. Profile History Table (Versioned computational attributes for reproducibility)
CREATE TABLE IF NOT EXISTS profile_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    attribute_name VARCHAR(64) NOT NULL,
    old_value JSONB,
    new_value JSONB NOT NULL,
    effective_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    actor VARCHAR(64) NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_profile_history_user_attr ON profile_history(user_id, attribute_name);

-- 7. Measurement Types (Catalog)
CREATE TABLE IF NOT EXISTS measurement_types (
    code VARCHAR(64) PRIMARY KEY,
    category VARCHAR(64) NOT NULL,
    dimension VARCHAR(32) NOT NULL,
    canonical_unit VARCHAR(32) NOT NULL,
    allowed_units VARCHAR(32)[] NOT NULL,
    min_plausible NUMERIC(12, 4) NOT NULL,
    max_plausible NUMERIC(12, 4) NOT NULL,
    laterality VARCHAR(16) NOT NULL DEFAULT 'none',
    is_user_enterable BOOLEAN NOT NULL DEFAULT true,
    is_derived BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. Provenance Records Table (Every health value must point to provenance)
CREATE TABLE IF NOT EXISTS provenance_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    origin_type VARCHAR(64) NOT NULL,
    epistemic_class VARCHAR(32) NOT NULL,
    actor VARCHAR(64) NOT NULL,
    method_version VARCHAR(64) NOT NULL,
    confidence_score NUMERIC(4, 3) NOT NULL,
    source_artifact_id UUID,
    review_state VARCHAR(32) NOT NULL DEFAULT 'unreviewed',
    observed_at TIMESTAMPTZ NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_provenance_user_observed ON provenance_records(user_id, observed_at DESC);

-- 9. Observations Table (Append-only facts)
CREATE TABLE IF NOT EXISTS observations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type_code VARCHAR(64) NOT NULL REFERENCES measurement_types(code),
    canonical_value NUMERIC(12, 4) NOT NULL,
    canonical_unit VARCHAR(32) NOT NULL,
    original_value NUMERIC(12, 4) NOT NULL,
    original_unit VARCHAR(32) NOT NULL,
    input_precision SMALLINT NOT NULL DEFAULT 1,
    observed_at TIMESTAMPTZ NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    time_zone VARCHAR(64) NOT NULL DEFAULT 'UTC',
    provenance_id UUID NOT NULL REFERENCES provenance_records(id),
    quality_flags VARCHAR(32)[] NOT NULL DEFAULT '{}',
    status VARCHAR(32) NOT NULL DEFAULT 'active',
    superseded_by UUID REFERENCES observations(id),
    supersedes UUID REFERENCES observations(id),
    voided_at TIMESTAMPTZ,
    void_reason TEXT
);
CREATE INDEX IF NOT EXISTS idx_obs_user_type_observed ON observations(user_id, type_code, observed_at DESC);
CREATE INDEX IF NOT EXISTS idx_obs_user_status ON observations(user_id, status);

-- 10. Audit Logs Table (Tamper-evident, content-free)
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    actor_type VARCHAR(32) NOT NULL,
    action VARCHAR(64) NOT NULL,
    entity_type VARCHAR(64) NOT NULL,
    entity_id VARCHAR(64) NOT NULL,
    correlation_id VARCHAR(64) NOT NULL,
    ip_address VARCHAR(45),
    status VARCHAR(16) NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_audit_user_action ON audit_logs(user_id, action, created_at DESC);

-- 11. Immutability & Provenance Trigger on Observations
CREATE OR REPLACE FUNCTION enforce_observation_immutability()
RETURNS TRIGGER AS $$
BEGIN
    -- Prohibit DELETE unless system privacy purge flag is set
    IF (TG_OP = 'DELETE') THEN
        IF (current_setting('app.allow_purge', true) = 'true') THEN
            RETURN OLD;
        ELSE
            RAISE EXCEPTION 'Hard deletion of observations is prohibited. Use voiding or account privacy purge.';
        END IF;
    END IF;

    -- On UPDATE: Disallow mutating immutable health fields
    IF (TG_OP = 'UPDATE') THEN
        IF (OLD.canonical_value != NEW.canonical_value OR
            OLD.original_value != NEW.original_value OR
            OLD.canonical_unit != NEW.canonical_unit OR
            OLD.original_unit != NEW.original_unit OR
            OLD.type_code != NEW.type_code OR
            OLD.observed_at != NEW.observed_at OR
            OLD.user_id != NEW.user_id OR
            OLD.provenance_id != NEW.provenance_id) THEN
            RAISE EXCEPTION 'Observations are immutable facts. Values cannot be updated. Use supersession to correct.';
        END IF;

        -- Only status, superseded_by, supersedes, voided_at, and void_reason may be updated
        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_observations_immutability ON observations;
CREATE TRIGGER trg_observations_immutability
BEFORE UPDATE OR DELETE ON observations
FOR EACH ROW EXECUTE FUNCTION enforce_observation_immutability();

-- 12. Row-Level Security Configuration
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE users FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS users_isolation ON users;
CREATE POLICY users_isolation ON users FOR ALL USING (
    id = NULLIF(current_setting('app.current_user_id', true), '')::uuid
    OR current_setting('app.is_system', true) = 'true'
) WITH CHECK (
    id = NULLIF(current_setting('app.current_user_id', true), '')::uuid
    OR current_setting('app.is_system', true) = 'true'
);

ALTER TABLE credentials ENABLE ROW LEVEL SECURITY;
ALTER TABLE credentials FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS credentials_isolation ON credentials;
CREATE POLICY credentials_isolation ON credentials FOR ALL USING (
    user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid
    OR current_setting('app.is_system', true) = 'true'
) WITH CHECK (
    user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid
    OR current_setting('app.is_system', true) = 'true'
);

ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS sessions_isolation ON sessions;
CREATE POLICY sessions_isolation ON sessions FOR ALL USING (
    user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid
    OR current_setting('app.is_system', true) = 'true'
) WITH CHECK (
    user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid
    OR current_setting('app.is_system', true) = 'true'
);

ALTER TABLE consents ENABLE ROW LEVEL SECURITY;
ALTER TABLE consents FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS consents_isolation ON consents;
CREATE POLICY consents_isolation ON consents FOR ALL USING (
    user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid
    OR current_setting('app.is_system', true) = 'true'
) WITH CHECK (
    user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid
    OR current_setting('app.is_system', true) = 'true'
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS profiles_isolation ON profiles;
CREATE POLICY profiles_isolation ON profiles FOR ALL USING (
    user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid
    OR current_setting('app.is_system', true) = 'true'
) WITH CHECK (
    user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid
    OR current_setting('app.is_system', true) = 'true'
);

ALTER TABLE profile_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE profile_history FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS profile_history_isolation ON profile_history;
CREATE POLICY profile_history_isolation ON profile_history FOR ALL USING (
    user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid
    OR current_setting('app.is_system', true) = 'true'
) WITH CHECK (
    user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid
    OR current_setting('app.is_system', true) = 'true'
);

ALTER TABLE provenance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE provenance_records FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS provenance_isolation ON provenance_records;
CREATE POLICY provenance_isolation ON provenance_records FOR ALL USING (
    user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid
    OR current_setting('app.is_system', true) = 'true'
) WITH CHECK (
    user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid
    OR current_setting('app.is_system', true) = 'true'
);

ALTER TABLE observations ENABLE ROW LEVEL SECURITY;
ALTER TABLE observations FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS observations_isolation ON observations;
CREATE POLICY observations_isolation ON observations FOR ALL USING (
    user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid
    OR current_setting('app.is_system', true) = 'true'
) WITH CHECK (
    user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid
    OR current_setting('app.is_system', true) = 'true'
);

ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS audit_logs_isolation ON audit_logs;
CREATE POLICY audit_logs_isolation ON audit_logs FOR ALL USING (
    user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid
    OR current_setting('app.is_system', true) = 'true'
) WITH CHECK (
    user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid
    OR current_setting('app.is_system', true) = 'true'
);
