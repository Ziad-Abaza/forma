-- ============================================================================
-- Migration 009: Integrations, Ingestion Batches, and Sync Deduplication Schema
-- Blueprint References: §14.2, §28.1, §32 Invariants 5, 6
-- ============================================================================

-- 1. Integration Connections (OAuth custody, status, granted scopes)
CREATE TABLE IF NOT EXISTS integration_connections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider VARCHAR(64) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'connected' CHECK (status IN ('connected', 'revoked', 'paused', 'error')),
    scopes JSONB NOT NULL DEFAULT '[]'::jsonb,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    last_synced_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_user_provider UNIQUE (user_id, provider)
);

CREATE INDEX IF NOT EXISTS idx_integration_connections_user_id ON integration_connections(user_id);

-- 2. Import Batches (Ingestion batch tracking, lineage, metrics)
CREATE TABLE IF NOT EXISTS import_batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    connection_id UUID REFERENCES integration_connections(id) ON DELETE SET NULL,
    provider VARCHAR(64) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'completed' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    records_count INTEGER NOT NULL DEFAULT 0,
    duplicates_count INTEGER NOT NULL DEFAULT 0,
    conflicts_count INTEGER NOT NULL DEFAULT 0,
    sync_cursor VARCHAR(256),
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    error_message TEXT
);

CREATE INDEX IF NOT EXISTS idx_import_batches_user_id ON import_batches(user_id);
CREATE INDEX IF NOT EXISTS idx_import_batches_connection_id ON import_batches(connection_id);

-- 3. Sync Deduplication Records (Idempotent re-sync via deterministic hash)
CREATE TABLE IF NOT EXISTS sync_dedup_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    connection_id UUID REFERENCES integration_connections(id) ON DELETE SET NULL,
    batch_id UUID REFERENCES import_batches(id) ON DELETE CASCADE,
    observation_id UUID REFERENCES observations(id) ON DELETE CASCADE,
    provider VARCHAR(64) NOT NULL,
    external_record_id VARCHAR(256) NOT NULL,
    dedup_hash VARCHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_user_dedup_hash UNIQUE (user_id, dedup_hash)
);

CREATE INDEX IF NOT EXISTS idx_sync_dedup_user_id ON sync_dedup_records(user_id);
CREATE INDEX IF NOT EXISTS idx_sync_dedup_hash ON sync_dedup_records(user_id, dedup_hash);

-- ============================================================================
-- 4. Double User Isolation: Row-Level Security Policies & Role Grants
-- ============================================================================

ALTER TABLE integration_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE integration_connections FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS integration_connections_isolation_policy ON integration_connections;
CREATE POLICY integration_connections_isolation_policy ON integration_connections
    FOR ALL
    USING (
        user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID
        OR current_setting('app.is_system', true) = 'true'
        OR current_setting('app.allow_purge', true) = 'true'
    )
    WITH CHECK (
        user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID
        OR current_setting('app.is_system', true) = 'true'
        OR current_setting('app.allow_purge', true) = 'true'
    );

ALTER TABLE import_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE import_batches FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS import_batches_isolation_policy ON import_batches;
CREATE POLICY import_batches_isolation_policy ON import_batches
    FOR ALL
    USING (
        user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID
        OR current_setting('app.is_system', true) = 'true'
        OR current_setting('app.allow_purge', true) = 'true'
    )
    WITH CHECK (
        user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID
        OR current_setting('app.is_system', true) = 'true'
        OR current_setting('app.allow_purge', true) = 'true'
    );

ALTER TABLE sync_dedup_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_dedup_records FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS sync_dedup_records_isolation_policy ON sync_dedup_records;
CREATE POLICY sync_dedup_records_isolation_policy ON sync_dedup_records
    FOR ALL
    USING (
        user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID
        OR current_setting('app.is_system', true) = 'true'
        OR current_setting('app.allow_purge', true) = 'true'
    )
    WITH CHECK (
        user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID
        OR current_setting('app.is_system', true) = 'true'
        OR current_setting('app.allow_purge', true) = 'true'
    );

-- 5. Grant permissions to non-superuser role forma_app
GRANT SELECT, INSERT, UPDATE, DELETE ON integration_connections TO forma_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON import_batches TO forma_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON sync_dedup_records TO forma_app;
