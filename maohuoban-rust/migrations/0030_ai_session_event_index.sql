-- AI Agent runtime session event append order
-- 核心职责：
-- - 为 replay 提供数据库写入顺序序号
-- - 避免同一 timestamp 下使用 UUID 排序破坏 append-only 顺序

ALTER TABLE ai_session_events
    ADD COLUMN IF NOT EXISTS event_index BIGSERIAL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_ai_session_events_event_index
    ON ai_session_events (event_index);

CREATE INDEX IF NOT EXISTS idx_ai_session_events_session_order
    ON ai_session_events (session_id, event_index ASC);

CREATE INDEX IF NOT EXISTS idx_ai_session_events_turn_order
    ON ai_session_events (turn_id, event_index ASC);
