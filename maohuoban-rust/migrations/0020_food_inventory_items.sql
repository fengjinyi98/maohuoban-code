-- 0020_food_inventory_items
-- 核心职责：
-- - 建立用户/家庭空间级储物柜食品资产表
-- - 供多宠共用，不绑定单一 pet_id
-- - 预留 household / merchant scope 扩展

CREATE TABLE IF NOT EXISTS food_inventory_items (
    id uuid PRIMARY KEY,
    scope_type text NOT NULL DEFAULT 'user',
    scope_id uuid NOT NULL,
    created_by_user_id uuid NOT NULL,
    name text NOT NULL,
    brand text,
    category text NOT NULL,
    inventory_status text NOT NULL DEFAULT 'active',
    quantity integer NOT NULL DEFAULT 1,
    unit text,
    spec text,
    expiry_date date,
    cover_asset_id uuid,
    barcode text,
    source_kind text NOT NULL DEFAULT 'manual',
    note text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    archived_at timestamptz,
    CONSTRAINT fk_food_inventory_created_by_user
        FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT ck_food_inventory_scope_type
        CHECK (scope_type IN ('user', 'household', 'merchant')),
    CONSTRAINT ck_food_inventory_category
        CHECK (category IN ('main_food', 'wet_food', 'treats', 'nutrition', 'other', 'cat_litter', 'medicine')),
    CONSTRAINT ck_food_inventory_status
        CHECK (inventory_status IN ('active', 'sealed', 'in_use', 'depleted', 'archived')),
    CONSTRAINT ck_food_inventory_source_kind
        CHECK (source_kind IN ('manual', 'barcode', 'ocr', 'order_imported', 'agent_confirmed')),
    CONSTRAINT ck_food_inventory_quantity_positive
        CHECK (quantity > 0)
);

CREATE INDEX IF NOT EXISTS idx_food_inventory_scope
    ON food_inventory_items(scope_type, scope_id);

CREATE INDEX IF NOT EXISTS idx_food_inventory_category
    ON food_inventory_items(scope_type, scope_id, category)
    WHERE archived_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_food_inventory_status
    ON food_inventory_items(scope_type, scope_id, inventory_status)
    WHERE archived_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_food_inventory_created_at
    ON food_inventory_items(scope_type, scope_id, created_at DESC);
