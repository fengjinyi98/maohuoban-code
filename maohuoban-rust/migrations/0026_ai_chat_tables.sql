-- AI 聊天会话、消息、审计日志表
-- 会话只保存宠物展示快照，不作为宠物事实权威来源

CREATE TABLE IF NOT EXISTS ai_chat_sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_user_id   UUID NOT NULL,
    primary_pet_id  UUID,
    surface         TEXT NOT NULL DEFAULT 'home_private',
    source_hint_id  UUID,
    source_task_id  UUID,
    title           TEXT NOT NULL DEFAULT '',
    pet_display_snapshot JSONB,
    status          TEXT NOT NULL DEFAULT 'active',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_chat_sessions_actor
    ON ai_chat_sessions (actor_user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS ai_messages (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id          UUID NOT NULL REFERENCES ai_chat_sessions(id) ON DELETE CASCADE,
    role                TEXT NOT NULL,
    content             TEXT NOT NULL DEFAULT '',
    status              TEXT NOT NULL DEFAULT 'completed',
    citations           JSONB NOT NULL DEFAULT '[]'::jsonb,
    model               TEXT,
    provider            TEXT,
    finish_reason       TEXT,
    usage_input_tokens  INTEGER,
    usage_output_tokens INTEGER,
    verification        JSONB,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_messages_session
    ON ai_messages (session_id, created_at ASC);

CREATE TABLE IF NOT EXISTS ai_tool_access_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id      UUID,
    actor_user_id   UUID NOT NULL,
    tool_name       TEXT NOT NULL,
    requested_scope TEXT NOT NULL DEFAULT '',
    target_pet_id   UUID,
    allowed         BOOLEAN NOT NULL DEFAULT false,
    denied_reason   TEXT,
    returned_ref_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
    duration_ms     BIGINT NOT NULL DEFAULT 0,
    risk_signal     TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_tool_access_logs_session
    ON ai_tool_access_logs (session_id, created_at ASC);

CREATE TABLE IF NOT EXISTS ai_request_gate_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id      UUID,
    actor_user_id   UUID NOT NULL,
    intent          TEXT NOT NULL DEFAULT '',
    gate_decision   TEXT NOT NULL DEFAULT '',
    context_loaded  BOOLEAN NOT NULL DEFAULT false,
    request_hash    TEXT NOT NULL DEFAULT '',
    resolved_pet_id UUID,
    selected_pet_id UUID,
    risk_signal     TEXT,
    estimated_input_tokens INTEGER NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_request_gate_logs_actor
    ON ai_request_gate_logs (actor_user_id, created_at DESC);
