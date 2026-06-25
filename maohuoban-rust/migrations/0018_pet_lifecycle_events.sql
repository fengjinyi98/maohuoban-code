-- 0018_pet_lifecycle_events
-- 核心职责：
-- - 用追加事件记录宠物生命状态变化
-- - 去世不删除档案，与 soft delete 分离

CREATE TABLE IF NOT EXISTS pet_lifecycle_events (
    id uuid PRIMARY KEY,
    pet_id uuid NOT NULL,
    event_kind text NOT NULL,
    from_guardian_type text,
    from_guardian_id uuid,
    to_guardian_type text,
    to_guardian_id uuid,
    actor_user_id uuid,
    source_ref_type text,
    source_ref_id uuid,
    note text,
    occurred_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_pet_lifecycle_events_pet
        FOREIGN KEY (pet_id) REFERENCES pet_profiles(id) ON DELETE CASCADE,
    CONSTRAINT fk_pet_lifecycle_events_actor
        FOREIGN KEY (actor_user_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT ck_pet_lifecycle_events_kind
        CHECK (
            event_kind IN (
                'created',
                'imported',
                'transferred',
                'adopted',
                'marked_deceased',
                'restored',
                'archived',
                'guardian_added',
                'guardian_revoked'
            )
        )
);

-- 为已有宠物补充 created 事件
INSERT INTO pet_lifecycle_events (
    id,
    pet_id,
    event_kind,
    actor_user_id,
    occurred_at,
    created_at
)
SELECT
    gen_random_uuid(),
    id,
    'created',
    owner_user_id,
    created_at,
    now()
FROM pet_profiles
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_pet_lifecycle_events_pet_occurred
    ON pet_lifecycle_events(pet_id, occurred_at DESC);
