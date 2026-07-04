-- 0042_food_inventory_structured_package
-- 核心职责：
-- - 为储物柜食品资产补充结构化包装规格
-- - 支撑后续库存消耗闭环和克数校准读模型

ALTER TABLE food_inventory_items
    ADD COLUMN IF NOT EXISTS package_weight_grams integer,
    ADD COLUMN IF NOT EXISTS package_count integer NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS package_unit text,
    ADD COLUMN IF NOT EXISTS production_date date,
    ADD COLUMN IF NOT EXISTS shelf_life_months integer;

ALTER TABLE food_inventory_items
    DROP CONSTRAINT IF EXISTS ck_food_inventory_package_weight_positive,
    ADD CONSTRAINT ck_food_inventory_package_weight_positive
        CHECK (package_weight_grams IS NULL OR package_weight_grams > 0);

ALTER TABLE food_inventory_items
    DROP CONSTRAINT IF EXISTS ck_food_inventory_package_count_positive,
    ADD CONSTRAINT ck_food_inventory_package_count_positive
        CHECK (package_count > 0);

ALTER TABLE food_inventory_items
    DROP CONSTRAINT IF EXISTS ck_food_inventory_shelf_life_months_positive,
    ADD CONSTRAINT ck_food_inventory_shelf_life_months_positive
        CHECK (shelf_life_months IS NULL OR shelf_life_months > 0);

ALTER TABLE food_inventory_items
    ALTER COLUMN inventory_status SET DEFAULT 'sealed';

ALTER TABLE food_inventory_items
    DROP CONSTRAINT IF EXISTS ck_food_inventory_status,
    ADD CONSTRAINT ck_food_inventory_status
        CHECK (inventory_status IN ('sealed', 'in_use', 'depleted', 'archived'));
