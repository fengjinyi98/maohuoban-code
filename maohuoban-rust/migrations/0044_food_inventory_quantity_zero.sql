-- 0044_food_inventory_quantity_zero
-- 核心职责：
-- - 允许库存数量在完整消耗后归零
-- - 支撑 depleted 状态表达真实已吃完语义

ALTER TABLE food_inventory_items
    DROP CONSTRAINT IF EXISTS ck_food_inventory_quantity_positive,
    ADD CONSTRAINT ck_food_inventory_quantity_non_negative
        CHECK (quantity >= 0);
