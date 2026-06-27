-- AI 聊天会话历史操作字段
-- 支持历史列表置顶、重命名和软删除排序

ALTER TABLE ai_chat_sessions
    ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_ai_chat_sessions_actor_active_order
    ON ai_chat_sessions (actor_user_id, is_pinned DESC, updated_at DESC)
    WHERE status = 'active';
