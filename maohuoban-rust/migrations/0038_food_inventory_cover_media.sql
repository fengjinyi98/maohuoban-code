-- 储物柜物品照片媒资用途
-- 核心职责：
-- - 允许用户级储物柜物品照片写入 media_assets
-- - 让 food_inventory_items.cover_asset_id 能引用真实媒资资产

ALTER TABLE media_assets
    DROP CONSTRAINT IF EXISTS ck_media_assets_usage_kind,
    ADD CONSTRAINT ck_media_assets_usage_kind
        CHECK (usage_kind IN (
            'pet.avatar',
            'pet.background.image',
            'pet.background.video',
            'pet.background.live_photo',
            'user.avatar',
            'user.cover.image',
            'pet.album.photo',
            'pet.food_inventory.cover'
        ));
