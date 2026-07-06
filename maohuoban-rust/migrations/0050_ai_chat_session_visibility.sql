-- 0050_ai_chat_session_visibility
-- 核心职责：
-- - 区分用户可见聊天记录与后台异常追踪上下文
-- - 记录异常上下文相对聊天记录的独立生命周期

ALTER TABLE ai_chat_sessions
    ADD COLUMN IF NOT EXISTS session_visibility text NOT NULL DEFAULT 'visible',
    ADD COLUMN IF NOT EXISTS context_status text NOT NULL DEFAULT 'active',
    ADD COLUMN IF NOT EXISTS activated_at timestamptz;

UPDATE ai_chat_sessions
SET session_visibility = 'background',
    activated_at = NULL,
    updated_at = now()
WHERE chat_context_kind = 'abnormal_episode_followup'
  AND status = 'active'
  AND last_turn_id IS NULL
  AND NOT EXISTS (
      SELECT 1
      FROM ai_messages m
      WHERE m.session_id = ai_chat_sessions.id
        AND m.role = 'user'
  );

UPDATE ai_chat_sessions
SET activated_at = COALESCE(activated_at, created_at)
WHERE session_visibility = 'visible'
  AND activated_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_ai_chat_sessions_actor_visible_order
    ON ai_chat_sessions (actor_user_id, is_pinned DESC, updated_at DESC)
    WHERE status = 'active' AND session_visibility = 'visible';
