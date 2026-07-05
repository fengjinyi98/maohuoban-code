-- 0048_agent_proactive_followups
-- 核心职责：
-- - 持久化 Agent 主动异常追踪计划
-- - 支撑调度器按 due_at 生成站内 abnormal_followup_due 轻提醒
-- - 保持 attention_hints 只承载当前可见待处理信号

ALTER TABLE abnormal_episodes
    ADD COLUMN IF NOT EXISTS next_followup_due_at timestamptz,
    ADD COLUMN IF NOT EXISTS last_followup_plan_id uuid;

CREATE TABLE IF NOT EXISTS agent_proactive_followups (
    id uuid PRIMARY KEY,
    pet_id uuid NOT NULL,
    episode_id uuid NOT NULL,
    trigger_event_id uuid,
    source_turn_id uuid,
    status text NOT NULL DEFAULT 'planning',
    due_at timestamptz NOT NULL,
    message_title text NOT NULL,
    message_body text NOT NULL,
    rationale text NOT NULL DEFAULT '',
    recommended_actions jsonb NOT NULL DEFAULT '[]',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    resolved_at timestamptz,
    CONSTRAINT fk_agent_proactive_followups_pet
        FOREIGN KEY (pet_id) REFERENCES pet_profiles(id) ON DELETE CASCADE,
    CONSTRAINT fk_agent_proactive_followups_episode
        FOREIGN KEY (episode_id) REFERENCES abnormal_episodes(id) ON DELETE CASCADE,
    CONSTRAINT fk_agent_proactive_followups_trigger_event
        FOREIGN KEY (trigger_event_id) REFERENCES pet_events(id) ON DELETE SET NULL,
    CONSTRAINT ck_agent_proactive_followups_status
        CHECK (status IN (
            'planning', 'scheduled', 'due', 'answered', 'resolved', 'cancelled', 'expired'
        ))
);

CREATE INDEX IF NOT EXISTS idx_agent_proactive_followups_due
    ON agent_proactive_followups(status, due_at)
    WHERE status = 'scheduled';

CREATE INDEX IF NOT EXISTS idx_agent_proactive_followups_episode
    ON agent_proactive_followups(episode_id, created_at DESC);

ALTER TABLE abnormal_episodes
    DROP CONSTRAINT IF EXISTS fk_abnormal_episodes_last_followup_plan;

ALTER TABLE abnormal_episodes
    ADD CONSTRAINT fk_abnormal_episodes_last_followup_plan
        FOREIGN KEY (last_followup_plan_id)
        REFERENCES agent_proactive_followups(id)
        ON DELETE SET NULL;

CREATE OR REPLACE FUNCTION project_due_agent_proactive_followups(now_at timestamptz)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    projected_count bigint;
BEGIN
    WITH due AS (
        UPDATE agent_proactive_followups
        SET status = 'due',
            updated_at = now()
        WHERE status = 'scheduled'
          AND due_at <= now_at
        RETURNING *
    ),
    inserted AS (
        INSERT INTO attention_hints (
            id, pet_id, kind, title, subtitle, icon, tone, priority,
            status, source_ref_type, source_ref_id,
            route_kind, route_payload, display_from, created_by,
            created_at, updated_at
        )
        SELECT
            gen_random_uuid(),
            due.pet_id,
            'abnormal_followup_due',
            due.message_title,
            due.message_body,
            'bubble.left.and.exclamationmark.bubble.right',
            'warning',
            20,
            'active',
            'agent_proactive_followup',
            due.id,
            'abnormal_detail',
            jsonb_build_object(
                'episode_id', due.episode_id,
                'event_id', due.trigger_event_id,
                'agent_followup_id', due.id,
                'default_action', 'update_observation',
                'actions', jsonb_build_array(
                    jsonb_build_object(
                        'id', 'update_observation',
                        'title', '更新情况',
                        'route_kind', 'abnormal_detail',
                        'presentation', jsonb_build_object(
                            'auto_open_sheet', 'abnormal_followup'
                        )
                    ),
                    jsonb_build_object(
                        'id', 'chat_with_agent',
                        'title', '问问毛球',
                        'route_kind', 'ai_chat',
                        'chat_context', jsonb_build_object(
                            'kind', 'abnormal_episode_followup',
                            'episode_id', due.episode_id,
                            'source_hint_id', NULL,
                            'agent_followup_id', due.id
                        )
                    )
                )
            ),
            due.due_at,
            'agent',
            now(),
            now()
        FROM due
        WHERE NOT EXISTS (
            SELECT 1
            FROM attention_hints existing
            WHERE existing.source_ref_type = 'agent_proactive_followup'
              AND existing.source_ref_id = due.id
              AND existing.status = 'active'
        )
        RETURNING id
    )
    SELECT COUNT(*) INTO projected_count FROM inserted;

    RETURN projected_count;
END;
$$;
