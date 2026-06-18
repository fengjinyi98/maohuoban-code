ALTER TABLE pet_profiles
    DROP CONSTRAINT IF EXISTS ck_pet_profiles_background_media_kind,
    ADD CONSTRAINT ck_pet_profiles_background_media_kind
        CHECK (background_media_kind IS NULL OR background_media_kind IN ('image', 'video', 'live_photo'));

ALTER TABLE media_assets
    DROP CONSTRAINT IF EXISTS ck_media_assets_usage_kind,
    ADD CONSTRAINT ck_media_assets_usage_kind
        CHECK (usage_kind IN ('pet.avatar', 'pet.background.image', 'pet.background.video', 'pet.background.live_photo'));

ALTER TABLE media_bindings
    DROP CONSTRAINT IF EXISTS ck_media_bindings_usage_kind,
    ADD CONSTRAINT ck_media_bindings_usage_kind
        CHECK (usage_kind IN ('pet.avatar', 'pet.background.image', 'pet.background.video', 'pet.background.live_photo'));

CREATE TABLE IF NOT EXISTS media_asset_components (
    id uuid PRIMARY KEY,
    asset_id uuid NOT NULL,
    component_kind text NOT NULL,
    bucket text NOT NULL,
    object_key text NOT NULL,
    mime_type text NOT NULL,
    byte_size bigint NOT NULL,
    sha256_hex text NOT NULL,
    width integer,
    height integer,
    duration_ms integer,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_media_asset_components_asset
        FOREIGN KEY (asset_id) REFERENCES media_assets(id) ON DELETE CASCADE,
    CONSTRAINT uq_media_asset_components_object UNIQUE (bucket, object_key),
    CONSTRAINT uq_media_asset_components_kind UNIQUE (asset_id, component_kind),
    CONSTRAINT ck_media_asset_components_kind
        CHECK (component_kind IN ('still', 'paired_video')),
    CONSTRAINT ck_media_asset_components_byte_size_positive
        CHECK (byte_size > 0),
    CONSTRAINT ck_media_asset_components_width_positive
        CHECK (width IS NULL OR width > 0),
    CONSTRAINT ck_media_asset_components_height_positive
        CHECK (height IS NULL OR height > 0),
    CONSTRAINT ck_media_asset_components_duration_positive
        CHECK (duration_ms IS NULL OR duration_ms > 0)
);

CREATE INDEX IF NOT EXISTS idx_media_asset_components_asset
    ON media_asset_components(asset_id, component_kind);
