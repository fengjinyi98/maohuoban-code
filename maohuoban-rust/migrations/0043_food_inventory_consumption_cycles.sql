-- 0043_food_inventory_consumption_cycles
-- 核心职责：
-- - 记录用户确认单个库存包装消耗完成的事实
-- - 为饮食趋势算法提供显式完整周期锚点

CREATE TABLE IF NOT EXISTS food_inventory_consumption_cycles (
    id uuid PRIMARY KEY,
    food_item_id uuid NOT NULL,
    scope_type text NOT NULL,
    scope_id uuid NOT NULL,
    confirmed_by_user_id uuid NOT NULL,
    sequence_no integer NOT NULL,
    consumed_quantity integer NOT NULL DEFAULT 1,
    package_weight_grams integer,
    package_unit text,
    confirmed_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_food_inventory_consumption_cycles_item
        FOREIGN KEY (food_item_id) REFERENCES food_inventory_items(id) ON DELETE CASCADE,
    CONSTRAINT fk_food_inventory_consumption_cycles_actor
        FOREIGN KEY (confirmed_by_user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT ck_food_inventory_consumption_cycles_scope_type
        CHECK (scope_type IN ('user', 'household', 'merchant')),
    CONSTRAINT ck_food_inventory_consumption_cycles_sequence_positive
        CHECK (sequence_no > 0),
    CONSTRAINT ck_food_inventory_consumption_cycles_quantity
        CHECK (consumed_quantity = 1),
    CONSTRAINT ck_food_inventory_consumption_cycles_weight_positive
        CHECK (package_weight_grams IS NULL OR package_weight_grams > 0),
    CONSTRAINT uq_food_inventory_consumption_cycles_item_sequence
        UNIQUE (food_item_id, sequence_no)
);

CREATE INDEX IF NOT EXISTS idx_food_inventory_consumption_cycles_item_time
    ON food_inventory_consumption_cycles(food_item_id, confirmed_at DESC);

CREATE INDEX IF NOT EXISTS idx_food_inventory_consumption_cycles_scope_time
    ON food_inventory_consumption_cycles(scope_type, scope_id, confirmed_at DESC);

ALTER TABLE food_inventory_item_changes
    DROP CONSTRAINT IF EXISTS ck_food_inventory_changes_kind;

ALTER TABLE food_inventory_item_changes
    ADD CONSTRAINT ck_food_inventory_changes_kind
        CHECK (change_kind IN ('created', 'updated', 'deleted', 'archived', 'restored', 'restocked', 'consumed'));
