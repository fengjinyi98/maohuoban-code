ALTER TABLE media_assets
    DROP CONSTRAINT IF EXISTS ck_media_assets_usage_kind,
    ADD CONSTRAINT ck_media_assets_usage_kind
        CHECK (usage_kind IN (
            'pet.avatar',
            'pet.background.image',
            'pet.background.video',
            'pet.background.live_photo',
            'user.avatar',
            'user.cover.image'
        ));

ALTER TABLE user_profiles
    ADD CONSTRAINT fk_user_profiles_avatar_asset
        FOREIGN KEY (avatar_asset_id) REFERENCES media_assets(id) ON DELETE SET NULL,
    ADD CONSTRAINT fk_user_profiles_cover_asset
        FOREIGN KEY (cover_asset_id) REFERENCES media_assets(id) ON DELETE SET NULL;
