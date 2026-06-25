-- 0016_pet_external_identifiers
-- 核心职责：
-- - 将芯片号等外部标识从 pet_profiles 主表迁出
-- - 支持标识生命周期（active/replaced/disputed/removed）
-- - 支持验证状态和证据资产绑定

CREATE TABLE IF NOT EXISTS pet_external_identifiers (
    id uuid PRIMARY KEY,
    pet_id uuid NOT NULL,
    identifier_type text NOT NULL,
    identifier_value text NOT NULL,
    issuer text,
    issued_at timestamptz,
    verified_status text NOT NULL DEFAULT 'unverified',
    status text NOT NULL DEFAULT 'active',
    evidence_asset_id uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_pet_external_identifiers_pet
        FOREIGN KEY (pet_id) REFERENCES pet_profiles(id) ON DELETE CASCADE,
    CONSTRAINT ck_pet_external_identifiers_type
        CHECK (identifier_type IN ('microchip')),
    CONSTRAINT ck_pet_external_identifiers_verified_status
        CHECK (verified_status IN ('unverified', 'self_reported', 'verified', 'rejected')),
    CONSTRAINT ck_pet_external_identifiers_status
        CHECK (status IN ('active', 'replaced', 'disputed', 'removed')),
    CONSTRAINT ck_pet_external_identifiers_value_not_empty
        CHECK (identifier_value <> '')
);

-- 迁移已有芯片号到外部标识表
INSERT INTO pet_external_identifiers (
    id,
    pet_id,
    identifier_type,
    identifier_value,
    verified_status,
    status,
    created_at,
    updated_at
)
SELECT
    gen_random_uuid(),
    id,
    'microchip',
    microchip_number,
    'self_reported',
    'active',
    now(),
    now()
FROM pet_profiles
WHERE microchip_number IS NOT NULL;

-- 索引
CREATE INDEX IF NOT EXISTS idx_pet_external_identifiers_pet_type_status
    ON pet_external_identifiers(pet_id, identifier_type, status);

CREATE INDEX IF NOT EXISTS idx_pet_external_identifiers_value
    ON pet_external_identifiers(identifier_type, identifier_value)
    WHERE status = 'active';
