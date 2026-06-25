-- 0021_pet_diet_assignments
-- 核心职责：
-- - 建立宠物对储物柜食品资产的消费配置关系
-- - 同一宠物同一时间只能有一个 active current_staple
-- - 多只宠物可以共用同一个 food_item_id

CREATE TABLE IF NOT EXISTS pet_diet_assignments (
    id uuid PRIMARY KEY,
    pet_id uuid NOT NULL,
    food_item_id uuid NOT NULL,
    role text NOT NULL,
    status text NOT NULL DEFAULT 'active',
    started_at timestamptz NOT NULL DEFAULT now(),
    ended_at timestamptz,
    reason text,
    created_by_user_id uuid NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_diet_assignments_pet
        FOREIGN KEY (pet_id) REFERENCES pet_profiles(id) ON DELETE CASCADE,
    CONSTRAINT fk_diet_assignments_food_item
        FOREIGN KEY (food_item_id) REFERENCES food_inventory_items(id) ON DELETE CASCADE,
    CONSTRAINT fk_diet_assignments_created_by_user
        FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT ck_diet_assignments_role
        CHECK (role IN (
            'current_staple', 'trying', 'usual_treat',
            'usual_nutrition', 'backup', 'not_suitable'
        )),
    CONSTRAINT ck_diet_assignments_status
        CHECK (status IN ('active', 'ended', 'archived'))
);

CREATE INDEX IF NOT EXISTS idx_diet_assignments_pet_active
    ON pet_diet_assignments(pet_id, status)
    WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_diet_assignments_pet_role
    ON pet_diet_assignments(pet_id, role, status);

CREATE INDEX IF NOT EXISTS idx_diet_assignments_food_item
    ON pet_diet_assignments(food_item_id);

-- 同一宠物同一时间只能有一个 active current_staple
CREATE UNIQUE INDEX IF NOT EXISTS uq_diet_assignments_pet_staple
    ON pet_diet_assignments(pet_id)
    WHERE role = 'current_staple' AND status = 'active';
