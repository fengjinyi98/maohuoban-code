-- 0015_pet_identity_phase1_life_status
-- 核心职责：
-- - 新增 life_status 和 origin_kind 字段
-- - life_status 与 deleted_at/managed_status 分离，去世不删除档案
-- - origin_kind 标记宠物档案不可变来源

ALTER TABLE pet_profiles
    ADD COLUMN IF NOT EXISTS life_status text NOT NULL DEFAULT 'alive',
    ADD COLUMN IF NOT EXISTS origin_kind text NOT NULL DEFAULT 'user_created';

-- 迁移已有数据的 origin_kind：从 source_kind 映射
-- user_created -> user_created
-- trade_imported -> trade_imported
-- merchant_managed -> merchant_created
-- litter_birth -> litter_birth
UPDATE pet_profiles
SET origin_kind = CASE source_kind
    WHEN 'user_created' THEN 'user_created'
    WHEN 'trade_imported' THEN 'trade_imported'
    WHEN 'merchant_managed' THEN 'merchant_created'
    WHEN 'litter_birth' THEN 'litter_birth'
    ELSE 'user_created'
END
WHERE origin_kind = 'user_created';

ALTER TABLE pet_profiles
    ADD CONSTRAINT ck_pet_profiles_life_status
        CHECK (life_status IN ('alive', 'deceased', 'lost', 'archived')),
    ADD CONSTRAINT ck_pet_profiles_origin_kind
        CHECK (origin_kind IN ('user_created', 'trade_imported', 'merchant_created', 'litter_birth', 'adopted'));
