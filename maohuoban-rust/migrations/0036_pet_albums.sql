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
            'pet.album.photo'
        ));

CREATE TABLE IF NOT EXISTS pet_albums (
    id uuid PRIMARY KEY,
    pet_id uuid NOT NULL,
    owner_user_id uuid NOT NULL,
    title text NOT NULL,
    description text,
    is_private boolean NOT NULL DEFAULT false,
    is_pinned boolean NOT NULL DEFAULT false,
    cover_asset_id uuid,
    photo_count integer NOT NULL DEFAULT 0,
    archived_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_pet_albums_pet
        FOREIGN KEY (pet_id) REFERENCES pet_profiles(id) ON DELETE CASCADE,
    CONSTRAINT fk_pet_albums_owner
        FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_pet_albums_cover_asset
        FOREIGN KEY (cover_asset_id) REFERENCES media_assets(id) ON DELETE SET NULL,
    CONSTRAINT ck_pet_albums_title_not_blank
        CHECK (length(btrim(title)) > 0),
    CONSTRAINT ck_pet_albums_photo_count_non_negative
        CHECK (photo_count >= 0)
);

CREATE INDEX IF NOT EXISTS idx_pet_albums_pet_keyset
    ON pet_albums(pet_id, is_pinned DESC, updated_at DESC, id DESC)
    WHERE archived_at IS NULL;

CREATE TABLE IF NOT EXISTS pet_album_assets (
    id uuid PRIMARY KEY,
    album_id uuid NOT NULL,
    pet_id uuid NOT NULL,
    asset_id uuid NOT NULL,
    added_by_user_id uuid NOT NULL,
    caption text,
    sort_taken_at timestamptz NOT NULL DEFAULT now(),
    removed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_pet_album_assets_album
        FOREIGN KEY (album_id) REFERENCES pet_albums(id) ON DELETE CASCADE,
    CONSTRAINT fk_pet_album_assets_pet
        FOREIGN KEY (pet_id) REFERENCES pet_profiles(id) ON DELETE CASCADE,
    CONSTRAINT fk_pet_album_assets_asset
        FOREIGN KEY (asset_id) REFERENCES media_assets(id) ON DELETE CASCADE,
    CONSTRAINT fk_pet_album_assets_added_by
        FOREIGN KEY (added_by_user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_pet_album_assets_active_asset
    ON pet_album_assets(album_id, asset_id)
    WHERE removed_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_pet_album_assets_album_keyset
    ON pet_album_assets(album_id, sort_taken_at DESC, created_at DESC, id DESC)
    WHERE removed_at IS NULL;
