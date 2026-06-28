-- AI Agent runtime session events
-- 核心职责：
-- - append-only 持久化 AgentSession emitted events
-- - 通过 session_id / turn_id 关联用户可见消息、工具、策略、provider 和 replay

CREATE TABLE IF NOT EXISTS ai_session_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id      UUID NOT NULL REFERENCES ai_chat_sessions(id) ON DELETE CASCADE,
    turn_id         UUID NOT NULL,
    parent_event_id UUID REFERENCES ai_session_events(id) ON DELETE SET NULL,
    event_name      TEXT NOT NULL,
    payload         JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_session_events_session
    ON ai_session_events (session_id, created_at ASC, id ASC);

CREATE INDEX IF NOT EXISTS idx_ai_session_events_turn
    ON ai_session_events (turn_id, created_at ASC, id ASC);

CREATE INDEX IF NOT EXISTS idx_ai_session_events_name
    ON ai_session_events (event_name, created_at DESC);
