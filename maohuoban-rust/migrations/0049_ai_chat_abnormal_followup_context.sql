-- 0049_ai_chat_abnormal_followup_context
-- 核心职责：
-- - 持久化从异常主动追踪轻提醒进入 AI 会话的上下文
-- - 让 Agent 会话可审计关联 abnormal_episode 和 agent_proactive_followup

ALTER TABLE ai_chat_sessions
    ADD COLUMN IF NOT EXISTS chat_context_kind text,
    ADD COLUMN IF NOT EXISTS abnormal_episode_id uuid,
    ADD COLUMN IF NOT EXISTS agent_followup_id uuid;

CREATE INDEX IF NOT EXISTS idx_ai_chat_sessions_abnormal_episode
    ON ai_chat_sessions (abnormal_episode_id, updated_at DESC)
    WHERE abnormal_episode_id IS NOT NULL;
