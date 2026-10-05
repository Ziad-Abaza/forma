-- ============================================================================
-- Migration 010: Integrations RLS Refinement
-- Refines Row-Level Security policies to safely handle empty string user settings
-- and allow system/purge context executions.
-- ============================================================================

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
