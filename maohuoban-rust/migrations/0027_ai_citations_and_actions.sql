-- AI 回答引用与建议动作表
-- 核心职责：
-- - 持久化助手消息引用的业务事实来源
-- - 持久化需要用户确认的 AI 建议动作

CREATE TABLE IF NOT EXISTS ai_message_citations (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id  UUID NOT NULL REFERENCES ai_messages(id) ON DELETE CASCADE,
    session_id  UUID NOT NULL REFERENCES ai_chat_sessions(id) ON DELETE CASCADE,
    source_kind TEXT NOT NULL,
    source_id   UUID NOT NULL,
    label       TEXT NOT NULL DEFAULT '',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ai_message_citations_source
        UNIQUE (message_id, source_kind, source_id)
);

CREATE INDEX IF NOT EXISTS idx_ai_message_citations_message
    ON ai_message_citations (message_id, created_at ASC);

CREATE INDEX IF NOT EXISTS idx_ai_message_citations_source
    ON ai_message_citations (source_kind, source_id);

CREATE TABLE IF NOT EXISTS ai_proposed_actions (
    id                   UUID PRIMARY KEY,
    session_id           UUID NOT NULL REFERENCES ai_chat_sessions(id) ON DELETE CASCADE,
    source_message_id    UUID REFERENCES ai_messages(id) ON DELETE SET NULL,
    action_kind          TEXT NOT NULL,
    target_pet_id        UUID NOT NULL,
    payload              JSONB NOT NULL DEFAULT '{}'::jsonb,
    confirm_text         TEXT NOT NULL DEFAULT '',
    risk_level           TEXT NOT NULL DEFAULT 'medium',
    confirmation_task_id UUID,
    status               TEXT NOT NULL DEFAULT 'pending',
    result               JSONB,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_ai_proposed_actions_status
        CHECK (status IN ('pending', 'confirmed', 'rejected', 'executed', 'failed'))
);

CREATE INDEX IF NOT EXISTS idx_ai_proposed_actions_session
    ON ai_proposed_actions (session_id, created_at ASC);

CREATE INDEX IF NOT EXISTS idx_ai_proposed_actions_pet_pending
    ON ai_proposed_actions (target_pet_id, status, created_at DESC);
