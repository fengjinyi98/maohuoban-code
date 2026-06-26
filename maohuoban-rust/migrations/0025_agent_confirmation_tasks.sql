-- 0025_agent_confirmation_tasks
-- 核心职责：
-- - 持久化 agent_confirmation_tasks 表，承载毛球 Agent 的结构化确认任务
-- - 任务不自动写入聊天消息；用户确认后才写 pet_events
-- - 可被首页轻提示、通知、聊天入口复用

CREATE TABLE IF NOT EXISTS agent_confirmation_tasks (
    id uuid PRIMARY KEY,
    pet_id uuid NOT NULL,
    task_kind text NOT NULL,
    question_text text NOT NULL,
    candidate_payload jsonb,
    source_hint_id uuid,
    source_ref_type text,
    source_ref_id uuid,
    status text NOT NULL DEFAULT 'pending',
    answer_payload jsonb,
    resolved_event_id uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    resolved_at timestamptz,
    CONSTRAINT fk_agent_confirmation_tasks_pet
        FOREIGN KEY (pet_id) REFERENCES pet_profiles(id) ON DELETE CASCADE,
    CONSTRAINT ck_agent_confirmation_tasks_task_kind
        CHECK (task_kind IN ('diet_change_confirmation', 'symptom_followup', 'risk_context_confirmation')),
    CONSTRAINT ck_agent_confirmation_tasks_status
        CHECK (status IN ('pending', 'answered', 'dismissed', 'expired'))
);

CREATE INDEX IF NOT EXISTS idx_agent_confirmation_tasks_pet_pending
    ON agent_confirmation_tasks(pet_id, created_at DESC)
    WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_agent_confirmation_tasks_pet_all
    ON agent_confirmation_tasks(pet_id, created_at DESC);
