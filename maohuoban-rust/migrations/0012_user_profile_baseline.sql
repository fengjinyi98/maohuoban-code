CREATE SEQUENCE IF NOT EXISTS users_join_sequence_seq;

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS join_sequence bigint;

ALTER TABLE users
    ALTER COLUMN join_sequence SET DEFAULT nextval('users_join_sequence_seq');

UPDATE users
SET join_sequence = nextval('users_join_sequence_seq')
WHERE join_sequence IS NULL;

ALTER TABLE users
    ALTER COLUMN join_sequence SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_join_sequence
    ON users(join_sequence);

CREATE TABLE IF NOT EXISTS user_profiles (
    user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    maohuoban_id text NOT NULL UNIQUE,
    display_name text NOT NULL,
    default_display_name text NOT NULL,
    bio text,
    gender text NOT NULL DEFAULT 'unknown',
    is_gender_visible boolean NOT NULL DEFAULT true,
    birthday date,
    region_country_code text,
    region_country_name text,
    region_province_code text,
    region_province_name text,
    region_city_code text,
    region_city_name text,
    region_district_code text,
    region_district_name text,
    avatar_asset_id uuid,
    cover_asset_id uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT user_profiles_gender_check
        CHECK (gender IN ('male', 'female', 'unknown')),
    CONSTRAINT user_profiles_birthday_check
        CHECK (birthday IS NULL OR birthday <= CURRENT_DATE)
);

CREATE INDEX IF NOT EXISTS idx_user_profiles_maohuoban_id
    ON user_profiles(maohuoban_id);

CREATE TABLE IF NOT EXISTS user_profile_field_changes (
    id uuid PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    field_name text NOT NULL,
    old_value text,
    new_value text,
    changed_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_profile_field_changes_user_field_changed
    ON user_profile_field_changes(user_id, field_name, changed_at DESC);
