-- Migration 006: AI Traces, BYOK Custody, and AI Platform Infrastructure
-- Phase 3: AI Context & Provider Infrastructure (Blueprint §12.8, §20.5, §27.1)

-- 1. AI Traces (Content-free operational & lineage ledger)
CREATE TABLE IF NOT EXISTS ai_traces (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    correlation_id VARCHAR(64) NOT NULL,
    provider VARCHAR(64) NOT NULL,
    model_id VARCHAR(128) NOT NULL,
    task_class VARCHAR(64) NOT NULL,
    intent_class VARCHAR(64) NOT NULL,
    context_tier INTEGER NOT NULL DEFAULT 1,
    context_manifest JSONB NOT NULL DEFAULT '{}'::jsonb,
    tools_invoked JSONB NOT NULL DEFAULT '[]'::jsonb,
    evidence_types JSONB NOT NULL DEFAULT '[]'::jsonb,
    safety_category VARCHAR(32) NOT NULL DEFAULT 'A',
    guardrails_triggered JSONB NOT NULL DEFAULT '[]'::jsonb,
    budget_consumed JSONB NOT NULL DEFAULT '{}'::jsonb,
    outcome VARCHAR(32) NOT NULL DEFAULT 'success',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_traces_user_created ON ai_traces(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_traces_correlation ON ai_traces(correlation_id);

-- 2. BYOK User AI Credentials (Encrypted secret custody framework)
CREATE TABLE IF NOT EXISTS user_ai_credentials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider VARCHAR(64) NOT NULL,
    encrypted_key TEXT NOT NULL,
    key_fingerprint VARCHAR(64) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_user_provider_cred UNIQUE(user_id, provider)
);

CREATE INDEX IF NOT EXISTS idx_user_ai_credentials_user ON user_ai_credentials(user_id);

-- 3. Row-Level Security Enforcement
ALTER TABLE ai_traces ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_traces FORCE ROW LEVEL SECURITY;

ALTER TABLE user_ai_credentials ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_ai_credentials FORCE ROW LEVEL SECURITY;

-- 4. RLS Policies for ai_traces
CREATE POLICY ai_traces_select_policy ON ai_traces
    FOR SELECT
    USING (user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID);

CREATE POLICY ai_traces_insert_policy ON ai_traces
    FOR INSERT
    WITH CHECK (user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID);

CREATE POLICY ai_traces_delete_policy ON ai_traces
    FOR DELETE
    USING (
        user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID
        OR NULLIF(current_setting('app.allow_purge', true), 'false')::BOOLEAN = true
    );

-- 5. RLS Policies for user_ai_credentials
CREATE POLICY user_ai_credentials_select_policy ON user_ai_credentials
    FOR SELECT
    USING (user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID);

CREATE POLICY user_ai_credentials_insert_policy ON user_ai_credentials
    FOR INSERT
    WITH CHECK (user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID);

CREATE POLICY user_ai_credentials_update_policy ON user_ai_credentials
    FOR UPDATE
    USING (user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID)
    WITH CHECK (user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID);

CREATE POLICY user_ai_credentials_delete_policy ON user_ai_credentials
    FOR DELETE
    USING (
        user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID
        OR NULLIF(current_setting('app.allow_purge', true), 'false')::BOOLEAN = true
    );

-- 6. Role Permissions for forma_app
GRANT SELECT, INSERT, UPDATE, DELETE ON ai_traces TO forma_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON user_ai_credentials TO forma_app;
