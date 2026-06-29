-- AI 会话摘要表
-- 持久化压缩后的结构化摘要，支持版本替代和压缩边界追踪

CREATE TABLE IF NOT EXISTS ai_chat_session_summaries (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chat_session_id             UUID NOT NULL REFERENCES ai_chat_sessions(id) ON DELETE CASCADE,
    scope_type                  TEXT NOT NULL DEFAULT 'user',
    scope_id                    UUID NOT NULL,
    summary_text                TEXT NOT NULL DEFAULT '',
    referenced_event_ids        JSONB NOT NULL DEFAULT '[]'::jsonb,
    token_budget_hint           INTEGER,
    compressed_until_message_id UUID,
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    superseded_at               TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_ai_chat_session_summaries_session
    ON ai_chat_session_summaries (chat_session_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_ai_chat_session_summaries_active
    ON ai_chat_session_summaries (chat_session_id)
    WHERE superseded_at IS NULL;
