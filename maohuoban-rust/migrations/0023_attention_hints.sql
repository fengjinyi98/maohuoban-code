-- 0023_attention_hints
-- 核心职责：
-- - 持久化 attention_hints 表，承载首页轻提示的创建、状态和来源引用
-- - 支持按宠物、类型、状态、优先级排序查询
-- - 保持 Reminder 独立，不共用同一语义

CREATE TABLE IF NOT EXISTS attention_hints (
    id uuid PRIMARY KEY,
    pet_id uuid NOT NULL,
    kind text NOT NULL,
    title text NOT NULL,
    subtitle text NOT NULL DEFAULT '',
    icon text NOT NULL DEFAULT '',
    tone text NOT NULL,
    priority int NOT NULL DEFAULT 0,
    status text NOT NULL DEFAULT 'active',
    source_ref_type text,
    source_ref_id uuid,
    route_kind text NOT NULL,
    route_payload jsonb,
    display_from timestamptz,
    display_until timestamptz,
    created_by text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    resolved_at timestamptz,
    CONSTRAINT fk_attention_hints_pet
        FOREIGN KEY (pet_id) REFERENCES pet_profiles(id) ON DELETE CASCADE,
    CONSTRAINT ck_attention_hints_kind
        CHECK (kind IN (
            'open_abnormal_episode', 'abnormal_followup_due', 'diet_change_confirmation',
            'preventive_care_due', 'reminder_due', 'weight_stale', 'feeding_pattern_changed'
        )),
    CONSTRAINT ck_attention_hints_tone
        CHECK (tone IN ('info', 'notice', 'warning', 'critical')),
    CONSTRAINT ck_attention_hints_status
        CHECK (status IN ('active', 'dismissed', 'resolved', 'expired')),
    CONSTRAINT ck_attention_hints_route_kind
        CHECK (route_kind IN (
            'abnormal_detail', 'confirmation_task', 'reminder_detail',
            'preventive_care_detail', 'weight_record', 'ai_chat'
        )),
    CONSTRAINT ck_attention_hints_created_by
        CHECK (created_by IN ('system', 'agent', 'user', 'business_rule'))
);

CREATE INDEX IF NOT EXISTS idx_attention_hints_pet_active
    ON attention_hints(pet_id, status, priority DESC, created_at DESC)
    WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_attention_hints_pet_all
    ON attention_hints(pet_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_attention_hints_source
    ON attention_hints(source_ref_type, source_ref_id);
