-- Migration 008: Media Artifacts & Multimodal Vision Extraction Drafts Schema
-- Phase 5: Image & Multimodal Intelligence (Blueprint §13, §14, §20.4, §27.1)

-- 1. Media Artifacts (Private storage metadata & integrity ledger)
CREATE TABLE IF NOT EXISTS media_artifacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    mime_type VARCHAR(64) NOT NULL,
    byte_size INTEGER NOT NULL,
    file_hash VARCHAR(64) NOT NULL,
    storage_path TEXT NOT NULL,
    image_kind VARCHAR(64) NOT NULL DEFAULT 'unknown', -- 'body_composition_report', 'scale_display', 'tape_measurement_sheet', 'nutrition_label', 'food_image', 'unknown'
    status VARCHAR(32) NOT NULL DEFAULT 'uploaded', -- 'uploaded', 'processing', 'extracted', 'retained', 'deleted'
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_media_artifacts_user_created ON media_artifacts(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_media_artifacts_hash ON media_artifacts(file_hash);

-- 2. Extraction Drafts (Intermediate structured extraction awaiting user review)
CREATE TABLE IF NOT EXISTS extraction_drafts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    media_artifact_id UUID REFERENCES media_artifacts(id) ON DELETE SET NULL,
    image_kind VARCHAR(64) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'draft', -- 'draft', 'reviewed', 'committed', 'discarded'
    extracted_fields JSONB NOT NULL DEFAULT '[]'::jsonb,
    overall_confidence NUMERIC(3,2) NOT NULL DEFAULT 1.0,
    requires_field_attention BOOLEAN NOT NULL DEFAULT FALSE,
    consistency_flags JSONB NOT NULL DEFAULT '[]'::jsonb,
    session_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    committed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_extraction_drafts_user_status ON extraction_drafts(user_id, status);
CREATE INDEX IF NOT EXISTS idx_extraction_drafts_artifact ON extraction_drafts(media_artifact_id);

-- 3. Row-Level Security Enforcement
ALTER TABLE media_artifacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE media_artifacts FORCE ROW LEVEL SECURITY;

ALTER TABLE extraction_drafts ENABLE ROW LEVEL SECURITY;
ALTER TABLE extraction_drafts FORCE ROW LEVEL SECURITY;

-- 4. RLS Policies for media_artifacts
CREATE POLICY media_artifacts_select_policy ON media_artifacts
    FOR SELECT
    USING (user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID);

CREATE POLICY media_artifacts_insert_policy ON media_artifacts
    FOR INSERT
    WITH CHECK (user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID);

CREATE POLICY media_artifacts_update_policy ON media_artifacts
    FOR UPDATE
    USING (user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID)
    WITH CHECK (user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID);

CREATE POLICY media_artifacts_delete_policy ON media_artifacts
    FOR DELETE
    USING (
        user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID
        OR current_setting('app.bypass_rls', true) = 'on'
    );

-- 5. RLS Policies for extraction_drafts
CREATE POLICY extraction_drafts_select_policy ON extraction_drafts
    FOR SELECT
    USING (user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID);

CREATE POLICY extraction_drafts_insert_policy ON extraction_drafts
    FOR INSERT
    WITH CHECK (user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID);

CREATE POLICY extraction_drafts_update_policy ON extraction_drafts
    FOR UPDATE
    USING (user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID)
    WITH CHECK (user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID);

CREATE POLICY extraction_drafts_delete_policy ON extraction_drafts
    FOR DELETE
    USING (
        user_id = NULLIF(current_setting('app.current_user_id', true), '')::UUID
        OR current_setting('app.bypass_rls', true) = 'on'
    );

-- 6. Role Grants for forma_app
DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'forma_app') THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON media_artifacts TO forma_app;
        GRANT SELECT, INSERT, UPDATE, DELETE ON extraction_drafts TO forma_app;
    END IF;
END $$;
