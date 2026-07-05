-- 0047_food_inventory_package_expiry_contract
-- 核心职责：
-- - 将生产日期和保质期月份收敛为食品有效期唯一输入源
-- - 保证数据库同时保存原始包装事实和后端派生过期日期

ALTER TABLE food_inventory_items
    ALTER COLUMN production_date SET NOT NULL,
    ALTER COLUMN shelf_life_months SET NOT NULL,
    ALTER COLUMN expiry_date SET NOT NULL;

ALTER TABLE food_inventory_items
    DROP CONSTRAINT IF EXISTS ck_food_inventory_shelf_life_months_positive,
    ADD CONSTRAINT ck_food_inventory_shelf_life_months_positive
        CHECK (shelf_life_months > 0);
