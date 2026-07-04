-- 0039_food_inventory_deleted_change_kind
-- 核心职责：
-- - 将储物柜移出动作的变化线索对齐为 deleted
-- - 保留旧 archived/restored 历史值的读取兼容

ALTER TABLE food_inventory_item_changes
    DROP CONSTRAINT IF EXISTS ck_food_inventory_changes_kind;

ALTER TABLE food_inventory_item_changes
    ADD CONSTRAINT ck_food_inventory_changes_kind
        CHECK (change_kind IN ('created', 'updated', 'deleted', 'archived', 'restored', 'restocked'));
