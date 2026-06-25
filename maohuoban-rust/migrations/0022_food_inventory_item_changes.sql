-- 0022_food_inventory_item_changes
-- 核心职责：
-- - 记录储物柜食品资产新增、编辑、归档、恢复和补库存变化
-- - 为 Agent 提供弱线索读模型来源

CREATE TABLE IF NOT EXISTS food_inventory_item_changes (
    id uuid PRIMARY KEY,
    food_item_id uuid NOT NULL,
    scope_type text NOT NULL,
    scope_id uuid NOT NULL,
    actor_user_id uuid NOT NULL,
    change_kind text NOT NULL,
    item_name text NOT NULL,
    item_category text NOT NULL,
    changed_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_food_inventory_changes_item
        FOREIGN KEY (food_item_id) REFERENCES food_inventory_items(id) ON DELETE CASCADE,
    CONSTRAINT fk_food_inventory_changes_actor
        FOREIGN KEY (actor_user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT ck_food_inventory_changes_scope_type
        CHECK (scope_type IN ('user', 'household', 'merchant')),
    CONSTRAINT ck_food_inventory_changes_kind
        CHECK (change_kind IN ('created', 'updated', 'archived', 'restored', 'restocked'))
);

CREATE INDEX IF NOT EXISTS idx_food_inventory_changes_scope_time
    ON food_inventory_item_changes(scope_type, scope_id, changed_at DESC);

CREATE INDEX IF NOT EXISTS idx_food_inventory_changes_item
    ON food_inventory_item_changes(food_item_id, changed_at DESC);
