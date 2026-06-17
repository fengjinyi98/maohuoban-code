ALTER TABLE media_assets
    ADD COLUMN IF NOT EXISTS width integer,
    ADD COLUMN IF NOT EXISTS height integer;

ALTER TABLE media_assets
    DROP CONSTRAINT IF EXISTS ck_media_assets_width_positive,
    ADD CONSTRAINT ck_media_assets_width_positive
        CHECK (width IS NULL OR width > 0);

ALTER TABLE media_assets
    DROP CONSTRAINT IF EXISTS ck_media_assets_height_positive,
    ADD CONSTRAINT ck_media_assets_height_positive
        CHECK (height IS NULL OR height > 0);
