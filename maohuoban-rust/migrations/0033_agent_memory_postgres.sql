-- Agent 记忆与偏好基础表
-- 核心职责：
-- - 使用 PostgreSQL 承载毛球 Agent 的权威记忆数据
-- - 支持用户 / 宠物 / 家庭 / 会话作用域隔离
-- - 先落结构化存储与检索过滤，向量索引由后续 pgvector migration 补充

CREATE TABLE IF NOT EXISTS agent_preferences (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scope_type         TEXT NOT NULL,
    scope_id           UUID NOT NULL,
    actor_user_id      UUID NOT NULL,
    agent_display_name TEXT,
    tone               TEXT,
    response_length    TEXT,
    enabled_capabilities JSONB NOT NULL DEFAULT '[]'::jsonb,
    source_ref         JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT ck_agent_preferences_scope
        CHECK (scope_type IN ('user', 'household')),
    CONSTRAINT ck_agent_preferences_response_length
        CHECK (response_length IS NULL OR response_length IN ('short', 'normal', 'detailed'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_agent_preferences_scope_actor
    ON agent_preferences (scope_type, scope_id, actor_user_id);

CREATE TABLE IF NOT EXISTS agent_memory_candidates (
    id                UUID PRIMARY KEY,
    scope_type        TEXT NOT NULL,
    scope_id          UUID NOT NULL,
    actor_user_id     UUID NOT NULL,
    candidate_kind    TEXT NOT NULL,
    summary           TEXT NOT NULL,
    source_message_id UUID,
    confidence        REAL NOT NULL DEFAULT 0,
    status            TEXT NOT NULL DEFAULT 'pending',
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    confirmed_at      TIMESTAMPTZ,
    CONSTRAINT ck_agent_memory_candidates_scope
        CHECK (scope_type IN ('user', 'pet', 'household', 'session')),
    CONSTRAINT ck_agent_memory_candidates_kind
        CHECK (candidate_kind IN (
            'preference_candidate',
            'profile_candidate',
            'pet_fact_candidate',
            'session_summary_candidate',
            'risk_signal'
        )),
    CONSTRAINT ck_agent_memory_candidates_status
        CHECK (status IN ('pending', 'confirmed', 'rejected', 'expired')),
    CONSTRAINT ck_agent_memory_candidates_confidence
        CHECK (confidence >= 0 AND confidence <= 1)
);

CREATE INDEX IF NOT EXISTS idx_agent_memory_candidates_pending_scope
    ON agent_memory_candidates (scope_type, scope_id, actor_user_id, created_at DESC)
    WHERE status = 'pending';

CREATE TABLE IF NOT EXISTS agent_profile_items (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scope_type    TEXT NOT NULL,
    scope_id      UUID NOT NULL,
    actor_user_id UUID NOT NULL,
    profile_kind  TEXT NOT NULL DEFAULT '',
    summary       TEXT NOT NULL,
    source_ref    JSONB NOT NULL DEFAULT '{}'::jsonb,
    confidence    REAL NOT NULL DEFAULT 0,
    status        TEXT NOT NULL DEFAULT 'active',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at    TIMESTAMPTZ,
    CONSTRAINT ck_agent_profile_items_scope
        CHECK (scope_type IN ('user', 'pet', 'household', 'session')),
    CONSTRAINT ck_agent_profile_items_status
        CHECK (status IN ('active', 'stale', 'deleted', 'pending_review')),
    CONSTRAINT ck_agent_profile_items_confidence
        CHECK (confidence >= 0 AND confidence <= 1)
);

CREATE INDEX IF NOT EXISTS idx_agent_profile_items_scope_active
    ON agent_profile_items (scope_type, scope_id, actor_user_id, updated_at DESC)
    WHERE status = 'active';

CREATE TABLE IF NOT EXISTS agent_memory_items (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scope_type    TEXT NOT NULL,
    scope_id      UUID NOT NULL,
    actor_user_id UUID NOT NULL,
    pet_id        UUID,
    household_id  UUID,
    memory_kind   TEXT NOT NULL,
    content       TEXT NOT NULL,
    summary       TEXT NOT NULL,
    source_ref    JSONB NOT NULL DEFAULT '{}'::jsonb,
    confidence    REAL NOT NULL DEFAULT 0,
    status        TEXT NOT NULL DEFAULT 'active',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at    TIMESTAMPTZ,
    CONSTRAINT ck_agent_memory_items_scope
        CHECK (scope_type IN ('user', 'pet', 'household', 'session')),
    CONSTRAINT ck_agent_memory_items_kind
        CHECK (memory_kind IN ('preference', 'profile', 'weak_memory', 'fact_reference', 'summary')),
    CONSTRAINT ck_agent_memory_items_status
        CHECK (status IN ('active', 'stale', 'deleted', 'pending_review')),
    CONSTRAINT ck_agent_memory_items_confidence
        CHECK (confidence >= 0 AND confidence <= 1)
);

CREATE INDEX IF NOT EXISTS idx_agent_memory_items_scope_active
    ON agent_memory_items (scope_type, scope_id, actor_user_id, updated_at DESC)
    WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_agent_memory_items_pet_active
    ON agent_memory_items (actor_user_id, pet_id, updated_at DESC)
    WHERE status = 'active' AND pet_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_agent_memory_items_household_active
    ON agent_memory_items (actor_user_id, household_id, updated_at DESC)
    WHERE status = 'active' AND household_id IS NOT NULL;
