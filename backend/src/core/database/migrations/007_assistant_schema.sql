-- Migration 007: Conversational Assistant, Multi-Turn Memory & Controlled Action Proposals
-- Phase 4: AI Assistant, Multi-Turn Memory, Streaming & Controlled Actions (Blueprint §10, §11, §12, §24, §27.1)

-- 1. Conversations (Threads & Rolling Summaries)
CREATE TABLE IF NOT EXISTS conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL DEFAULT 'New Conversation',
    summary TEXT,
    rolling_summary TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_conversations_user_updated ON conversations(user_id, updated_at DESC);

-- 2. Conversation Messages
CREATE TABLE IF NOT EXISTS conversation_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(32) NOT NULL, -- 'user', 'assistant', 'system', 'tool'
    content TEXT NOT NULL,
    evidence_claims JSONB NOT NULL DEFAULT '[]'::jsonb,
    proposals JSONB NOT NULL DEFAULT '[]'::jsonb,
    token_count INTEGER NOT NULL DEFAULT 0,
    safety_category VARCHAR(32) NOT NULL DEFAULT 'A',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_messages_conversation_created ON conversation_messages(conversation_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_messages_user_created ON conversation_messages(user_id, created_at DESC);

-- 3. Action Proposals (Propose -> Confirm -> Commit Protocol)
CREATE TABLE IF NOT EXISTS action_proposals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    conversation_id UUID REFERENCES conversations(id) ON DELETE SET NULL,
    message_id UUID REFERENCES conversation_messages(id) ON DELETE SET NULL,
    action_type VARCHAR(64) NOT NULL, -- e.g., 'log_measurement', 'update_goal', 'save_memory'
    parameters JSONB NOT NULL DEFAULT '{}'::jsonb,
    diff_preview JSONB NOT NULL DEFAULT '{}'::jsonb,
    human_readable_summary TEXT NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'pending', -- 'pending', 'confirmed', 'declined', 'expired', 'executed', 'failed'
    idempotency_key VARCHAR(128) NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    executed_at TIMESTAMPTZ,
    receipt JSONB, -- Immutable Action Receipt once committed
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_action_proposals_user_status ON action_proposals(user_id, status);
CREATE INDEX IF NOT EXISTS idx_action_proposals_idempotency ON action_proposals(idempotency_key);

-- 4. Assistant Memories (Durable User Facts, Preferences & Routines)
CREATE TABLE IF NOT EXISTS assistant_memories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category VARCHAR(64) NOT NULL, -- 'preference', 'fact', 'routine', 'constraint'
    key VARCHAR(128) NOT NULL,
    value TEXT NOT NULL,
    confidence NUMERIC(3,2) NOT NULL DEFAULT 1.0,
    source VARCHAR(64) NOT NULL DEFAULT 'assistant_proposal',
    provenance_id UUID,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_user_category_key UNIQUE (user_id, category, key)
);

CREATE INDEX IF NOT EXISTS idx_assistant_memories_user_active ON assistant_memories(user_id, is_active);

-- 5. Row-Level Security Enforcement
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations FORCE ROW LEVEL SECURITY;

ALTER TABLE conversation_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_messages FORCE ROW LEVEL SECURITY;

ALTER TABLE action_proposals ENABLE ROW LEVEL SECURITY;
ALTER TABLE action_proposals FORCE ROW LEVEL SECURITY;

ALTER TABLE assistant_memories ENABLE ROW LEVEL SECURITY;
ALTER TABLE assistant_memories FORCE ROW LEVEL SECURITY;

-- 6. RLS Policies for conversations
CREATE POLICY conversations_select_policy ON conversations
    FOR SELECT
    USING (user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID);

CREATE POLICY conversations_insert_policy ON conversations
    FOR INSERT
    WITH CHECK (user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID);

CREATE POLICY conversations_update_policy ON conversations
    FOR UPDATE
    USING (user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID)
    WITH CHECK (user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID);

CREATE POLICY conversations_delete_policy ON conversations
    FOR DELETE
    USING (
        user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID
        OR current_setting('app.bypass_rls', true) = 'on'
    );

-- 7. RLS Policies for conversation_messages
CREATE POLICY conversation_messages_select_policy ON conversation_messages
    FOR SELECT
    USING (user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID);

CREATE POLICY conversation_messages_insert_policy ON conversation_messages
    FOR INSERT
    WITH CHECK (user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID);

CREATE POLICY conversation_messages_update_policy ON conversation_messages
    FOR UPDATE
    USING (user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID)
    WITH CHECK (user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID);

CREATE POLICY conversation_messages_delete_policy ON conversation_messages
    FOR DELETE
    USING (
        user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID
        OR current_setting('app.bypass_rls', true) = 'on'
    );

-- 8. RLS Policies for action_proposals
CREATE POLICY action_proposals_select_policy ON action_proposals
    FOR SELECT
    USING (user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID);

CREATE POLICY action_proposals_insert_policy ON action_proposals
    FOR INSERT
    WITH CHECK (user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID);

CREATE POLICY action_proposals_update_policy ON action_proposals
    FOR UPDATE
    USING (user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID)
    WITH CHECK (user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID);

CREATE POLICY action_proposals_delete_policy ON action_proposals
    FOR DELETE
    USING (
        user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID
        OR current_setting('app.bypass_rls', true) = 'on'
    );

-- 9. RLS Policies for assistant_memories
CREATE POLICY assistant_memories_select_policy ON assistant_memories
    FOR SELECT
    USING (user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID);

CREATE POLICY assistant_memories_insert_policy ON assistant_memories
    FOR INSERT
    WITH CHECK (user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID);

CREATE POLICY assistant_memories_update_policy ON assistant_memories
    FOR UPDATE
    USING (user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID)
    WITH CHECK (user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID);

CREATE POLICY assistant_memories_delete_policy ON assistant_memories
    FOR DELETE
    USING (
        user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID
        OR current_setting('app.bypass_rls', true) = 'on'
    );

-- 10. Role Grants for forma_app
DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'forma_app') THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON conversations TO forma_app;
        GRANT SELECT, INSERT, UPDATE, DELETE ON conversation_messages TO forma_app;
        GRANT SELECT, INSERT, UPDATE, DELETE ON action_proposals TO forma_app;
        GRANT SELECT, INSERT, UPDATE, DELETE ON assistant_memories TO forma_app;
    END IF;
END $$;
