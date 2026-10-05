-- Migration 005: Phase 2 Schema (Goals, Goal Versions, Health Snapshots, Metric Rollups, Anomaly Flags)

CREATE TABLE IF NOT EXISTS goals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    goal_type VARCHAR(50) NOT NULL, -- 'weight_loss', 'muscle_gain', 'maintenance', 'general_fitness'
    target_metric_type_code VARCHAR(64) NOT NULL REFERENCES measurement_types(code),
    is_primary BOOLEAN NOT NULL DEFAULT true,
    status VARCHAR(30) NOT NULL DEFAULT 'active', -- 'active', 'achieved', 'abandoned', 'superseded'
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_goals_user ON goals(user_id);
ALTER TABLE goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE goals FORCE ROW LEVEL SECURITY;

CREATE POLICY user_isolation_goals ON goals
    USING (user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid)
    WITH CHECK (user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid);

GRANT SELECT, INSERT, UPDATE, DELETE ON goals TO forma_app;


CREATE TABLE IF NOT EXISTS goal_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    goal_id UUID NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    version INT NOT NULL DEFAULT 1,
    target_value NUMERIC(10, 4) NOT NULL,
    starting_value NUMERIC(10, 4) NOT NULL,
    weekly_rate NUMERIC(10, 4),
    start_date DATE NOT NULL,
    target_date DATE,
    rationale TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_goal_version UNIQUE (goal_id, version)
);

CREATE INDEX IF NOT EXISTS idx_goal_versions_user ON goal_versions(user_id);
CREATE INDEX IF NOT EXISTS idx_goal_versions_goal ON goal_versions(goal_id);
ALTER TABLE goal_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE goal_versions FORCE ROW LEVEL SECURITY;

CREATE POLICY user_isolation_goal_versions ON goal_versions
    USING (user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid)
    WITH CHECK (user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid);

GRANT SELECT, INSERT, UPDATE, DELETE ON goal_versions TO forma_app;


CREATE TABLE IF NOT EXISTS health_snapshots (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    snapshot_version INT NOT NULL DEFAULT 1,
    source_data_watermark VARCHAR(100) NOT NULL,
    sections JSONB NOT NULL DEFAULT '{}'::jsonb,
    reconciled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE health_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE health_snapshots FORCE ROW LEVEL SECURITY;

CREATE POLICY user_isolation_health_snapshots ON health_snapshots
    USING (user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid)
    WITH CHECK (user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid);

GRANT SELECT, INSERT, UPDATE, DELETE ON health_snapshots TO forma_app;


CREATE TABLE IF NOT EXISTS metric_rollups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    measurement_type_code VARCHAR(64) NOT NULL REFERENCES measurement_types(code),
    period_type VARCHAR(20) NOT NULL, -- 'daily', 'weekly', 'monthly'
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    count INT NOT NULL,
    mean_value NUMERIC(12, 4),
    min_value NUMERIC(12, 4),
    max_value NUMERIC(12, 4),
    first_value NUMERIC(12, 4),
    last_value NUMERIC(12, 4),
    sum_value NUMERIC(12, 4),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_user_metric_rollup UNIQUE (user_id, measurement_type_code, period_type, period_start)
);

CREATE INDEX IF NOT EXISTS idx_metric_rollups_user ON metric_rollups(user_id);
ALTER TABLE metric_rollups ENABLE ROW LEVEL SECURITY;
ALTER TABLE metric_rollups FORCE ROW LEVEL SECURITY;

CREATE POLICY user_isolation_metric_rollups ON metric_rollups
    USING (user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid)
    WITH CHECK (user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid);

GRANT SELECT, INSERT, UPDATE, DELETE ON metric_rollups TO forma_app;


CREATE TABLE IF NOT EXISTS anomaly_flags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    observation_id UUID NOT NULL REFERENCES observations(id) ON DELETE CASCADE,
    flag_type VARCHAR(50) NOT NULL, -- 'implausible_jump', 'unit_mismatch_suspect', 'extreme_outlier'
    severity VARCHAR(20) NOT NULL DEFAULT 'warning', -- 'info', 'warning', 'critical'
    details JSONB NOT NULL DEFAULT '{}'::jsonb,
    dismissed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_anomaly_flags_user ON anomaly_flags(user_id);
ALTER TABLE anomaly_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE anomaly_flags FORCE ROW LEVEL SECURITY;

CREATE POLICY user_isolation_anomaly_flags ON anomaly_flags
    USING (user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid)
    WITH CHECK (user_id = NULLIF(current_setting('app.current_user_id', true), '')::uuid);

GRANT SELECT, INSERT, UPDATE, DELETE ON anomaly_flags TO forma_app;
