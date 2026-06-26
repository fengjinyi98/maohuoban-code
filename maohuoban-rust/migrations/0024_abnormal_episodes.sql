-- 0024_abnormal_episodes
-- 核心职责：
-- - 持久化 abnormal_episodes 表，承载异常追踪闭环的状态和症状
-- - 约束关闭或恢复的 episode 不能删除历史事件
-- - 所有 pet_events 通过 episode_id 追踪到同一 episode

CREATE TABLE IF NOT EXISTS abnormal_episodes (
    id uuid PRIMARY KEY,
    pet_id uuid NOT NULL,
    status text NOT NULL DEFAULT 'open',
    primary_symptom_kind text NOT NULL,
    symptom_kinds jsonb NOT NULL DEFAULT '[]',
    severity text NOT NULL,
    started_at timestamptz NOT NULL,
    last_observed_at timestamptz,
    recovered_at timestamptz,
    created_by_user_id uuid NOT NULL,
    created_event_id uuid NOT NULL,
    latest_event_id uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_abnormal_episodes_pet
        FOREIGN KEY (pet_id) REFERENCES pet_profiles(id) ON DELETE CASCADE,
    CONSTRAINT ck_abnormal_episodes_status
        CHECK (status IN ('open', 'watching', 'recovering', 'recovered', 'escalated', 'closed')),
    CONSTRAINT ck_abnormal_episodes_primary_symptom
        CHECK (primary_symptom_kind IN (
            'appetite', 'energy', 'stool', 'vomit', 'skin', 'eye', 'ear',
            'mouth', 'respiratory', 'urinary', 'mobility', 'weight', 'behavior', 'other'
        )),
    CONSTRAINT ck_abnormal_episodes_severity
        CHECK (severity IN ('mild', 'obvious', 'severe'))
);

CREATE INDEX IF NOT EXISTS idx_abnormal_episodes_pet_open
    ON abnormal_episodes(pet_id, created_at DESC)
    WHERE status IN ('open', 'watching', 'recovering');

CREATE INDEX IF NOT EXISTS idx_abnormal_episodes_pet_all
    ON abnormal_episodes(pet_id, created_at DESC);

-- abnormal_symptom payload 结构约束函数
-- 注意：pet_events.event_payload 存储为 jsonb，应用层校验即可
-- 核心 payload 字段约定：
-- - abnormal_symptom: { episode_id, symptom_kinds, symptom_details, severity, note, attachment_asset_ids }
-- - symptom_followup: { episode_id, condition_change, symptom_kinds, note, attachment_asset_ids }
-- - clinic_visit_linked: { episode_id, clinic_visit_event_id, linked_by_user_id }
-- - abnormal_recovery: { episode_id, recovered_at, recovery_note }
