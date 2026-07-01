-- AI 消息结构化内容块
-- 核心职责：
-- - 持久化前端原生渲染所需的内容块 DTO
-- - 保证历史回放与实时流式完成事件使用同一展示契约

ALTER TABLE ai_messages
    ADD COLUMN IF NOT EXISTS content_blocks JSONB NOT NULL DEFAULT '[]'::jsonb;
