-- 0017_pet_guardians
-- 核心职责：
-- - 承载用户、商家、共管者与宠物的当前/历史关系
-- - 不复制宠物主数据，只表达归属关系

CREATE TABLE IF NOT EXISTS pet_guardians (
    id uuid PRIMARY KEY,
    pet_id uuid NOT NULL,
    guardian_type text NOT NULL,
    guardian_user_id uuid,
    guardian_merchant_id uuid,
    role text NOT NULL,
    status text NOT NULL DEFAULT 'active',
    started_at timestamptz NOT NULL DEFAULT now(),
    ended_at timestamptz,
    granted_by_user_id uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_pet_guardians_pet
        FOREIGN KEY (pet_id) REFERENCES pet_profiles(id) ON DELETE CASCADE,
    CONSTRAINT fk_pet_guardians_user
        FOREIGN KEY (guardian_user_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT fk_pet_guardians_merchant
        FOREIGN KEY (guardian_merchant_id) REFERENCES merchant_profiles(id) ON DELETE SET NULL,
    CONSTRAINT fk_pet_guardians_granted_by
        FOREIGN KEY (granted_by_user_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT ck_pet_guardians_subject
        CHECK (guardian_user_id IS NOT NULL OR guardian_merchant_id IS NOT NULL),
    CONSTRAINT ck_pet_guardians_type
        CHECK (guardian_type IN ('user', 'merchant')),
    CONSTRAINT ck_pet_guardians_role
        CHECK (role IN ('owner', 'co_caretaker', 'merchant_manager', 'previous_owner')),
    CONSTRAINT ck_pet_guardians_status
        CHECK (status IN ('active', 'transferred', 'revoked', 'archived'))
);

-- 迁移已有 owner 关系到 pet_guardians
INSERT INTO pet_guardians (
    id,
    pet_id,
    guardian_type,
    guardian_user_id,
    role,
    status,
    started_at,
    created_at,
    updated_at
)
SELECT
    gen_random_uuid(),
    id,
    'user',
    owner_user_id,
    'owner',
    'active',
    created_at,
    created_at,
    created_at
FROM pet_profiles
WHERE owner_user_id IS NOT NULL;

-- 迁移已有商家关系到 pet_guardians
INSERT INTO pet_guardians (
    id,
    pet_id,
    guardian_type,
    guardian_merchant_id,
    role,
    status,
    started_at,
    created_at,
    updated_at
)
SELECT
    gen_random_uuid(),
    id,
    'merchant',
    merchant_id,
    'merchant_manager',
    'active',
    created_at,
    created_at,
    created_at
FROM pet_profiles
WHERE merchant_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_pet_guardians_pet_role_status
    ON pet_guardians(pet_id, role, status);

CREATE INDEX IF NOT EXISTS idx_pet_guardians_user_active
    ON pet_guardians(guardian_user_id, status)
    WHERE guardian_user_id IS NOT NULL AND status = 'active';

CREATE INDEX IF NOT EXISTS idx_pet_guardians_merchant_active
    ON pet_guardians(guardian_merchant_id, status)
    WHERE guardian_merchant_id IS NOT NULL AND status = 'active';
