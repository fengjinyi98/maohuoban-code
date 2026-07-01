-- AI session turns 表
-- 核心职责：
-- - turn 作为数据库一等对象，承载一次完整 Agent 执行单元
-- - 关联 user message、assistant message、runtime event 和 provider diagnostics
-- - 统一 turn 级状态、意图、gate 摘要和终态信息

CREATE TABLE IF NOT EXISTS ai_session_turns (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id           UUID NOT NULL REFERENCES ai_chat_sessions(id) ON DELETE CASCADE,
    actor_user_id        UUID NOT NULL,
    user_message_id      UUID NOT NULL REFERENCES ai_messages(id) ON DELETE RESTRICT,
    assistant_message_id UUID REFERENCES ai_messages(id) ON DELETE SET NULL,
    intent               TEXT NOT NULL DEFAULT '',
    gate_decision        TEXT NOT NULL DEFAULT '',
    resolved_pet_id      UUID,
    engine_mode          TEXT NOT NULL DEFAULT 'self_hosted',
    surface              TEXT NOT NULL DEFAULT 'home_private',
    status               TEXT NOT NULL DEFAULT 'running',
    finish_reason        TEXT,
    error_code           TEXT,
    retryable            BOOLEAN,
    started_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at          TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_ai_session_turns_session
    ON ai_session_turns (session_id, started_at ASC);

CREATE INDEX IF NOT EXISTS idx_ai_session_turns_actor
    ON ai_session_turns (actor_user_id, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_ai_session_turns_status
    ON ai_session_turns (status, started_at DESC);

-- ai_messages 补 turn_id 列，transcript 绑定 turn
-- FK 使用 DEFERRABLE INITIALLY DEFERRED，因为 ai_session_turns.user_message_id 反向引用 ai_messages(id)，
-- 形成循环依赖；延迟约束允许在同一事务内先插消息再插 turn 行。
ALTER TABLE ai_messages
    ADD COLUMN IF NOT EXISTS turn_id UUID;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'ai_messages_turn_id_fkey'
    ) THEN
        ALTER TABLE ai_messages
            ADD CONSTRAINT ai_messages_turn_id_fkey
            FOREIGN KEY (turn_id) REFERENCES ai_session_turns(id)
            ON DELETE SET NULL
            DEFERRABLE INITIALLY DEFERRED;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_ai_messages_turn
    ON ai_messages (turn_id, created_at ASC);

-- ai_chat_sessions 补 last_message_at 和 last_turn_id
ALTER TABLE ai_chat_sessions
    ADD COLUMN IF NOT EXISTS last_message_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS last_turn_id UUID;
