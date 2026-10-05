-- Migration 012: Chat System v2 AI Traces Enhancements
-- Phase P1/P4: Support prompt_version, response_tier, format_violations, language_mismatch, latency_ms in AI traces

ALTER TABLE ai_traces ADD COLUMN IF NOT EXISTS prompt_version VARCHAR(32) DEFAULT '2.0.0';
ALTER TABLE ai_traces ADD COLUMN IF NOT EXISTS response_tier VARCHAR(16) DEFAULT 'T1';
ALTER TABLE ai_traces ADD COLUMN IF NOT EXISTS format_violations INTEGER DEFAULT 0;
ALTER TABLE ai_traces ADD COLUMN IF NOT EXISTS language_mismatch BOOLEAN DEFAULT FALSE;
ALTER TABLE ai_traces ADD COLUMN IF NOT EXISTS latency_ms INTEGER DEFAULT 0;
