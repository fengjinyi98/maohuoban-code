-- 0046_food_inventory_cycle_check_change_kind
-- 核心职责：
-- - 记录用户对首个库存周期确认提醒的“还在吃”处理
-- - 为首页轻提醒冷却提供后端事实来源

ALTER TABLE food_inventory_item_changes
    DROP CONSTRAINT IF EXISTS ck_food_inventory_changes_kind;

ALTER TABLE food_inventory_item_changes
    ADD CONSTRAINT ck_food_inventory_changes_kind
        CHECK (change_kind IN (
            'created', 'updated', 'deleted', 'archived', 'restored',
            'restocked', 'consumed', 'cycle_checked_still_using'
        ));
