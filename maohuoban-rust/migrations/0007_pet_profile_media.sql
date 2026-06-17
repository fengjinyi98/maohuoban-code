ALTER TABLE pet_profiles
    ADD COLUMN IF NOT EXISTS profile_number text,
    ADD COLUMN IF NOT EXISTS microchip_number text,
    ADD COLUMN IF NOT EXISTS arrival_date date,
    ADD COLUMN IF NOT EXISTS weight_grams integer,
    ADD COLUMN IF NOT EXISTS neuter_status text NOT NULL DEFAULT 'unknown',
    ADD COLUMN IF NOT EXISTS personality_tags jsonb NOT NULL DEFAULT '[]'::jsonb,
    ADD COLUMN IF NOT EXISTS note text,
    ADD COLUMN IF NOT EXISTS background_asset_id uuid,
    ADD COLUMN IF NOT EXISTS background_media_kind text,
    ADD COLUMN IF NOT EXISTS deleted_at timestamptz,
    ADD COLUMN IF NOT EXISTS delete_requested_by_user_id uuid,
    ADD COLUMN IF NOT EXISTS recoverable_until timestamptz,
    ADD COLUMN IF NOT EXISTS delete_reason text;

UPDATE pet_profiles
SET profile_number = lpad((abs(('x' || substr(md5(id::text), 1, 15))::bit(60)::bigint) % 10000000000000000)::text, 16, '0')
WHERE profile_number IS NULL;

ALTER TABLE pet_profiles
    ALTER COLUMN profile_number SET NOT NULL;

ALTER TABLE pet_profiles
    ADD CONSTRAINT uq_pet_profiles_profile_number UNIQUE (profile_number),
    ADD CONSTRAINT uq_pet_profiles_microchip_number UNIQUE (microchip_number),
    ADD CONSTRAINT fk_pet_profiles_delete_requested_by
        FOREIGN KEY (delete_requested_by_user_id) REFERENCES users(id) ON DELETE SET NULL,
    ADD CONSTRAINT ck_pet_profiles_profile_number_digits
        CHECK (profile_number ~ '^[0-9]{16}$'),
    ADD CONSTRAINT ck_pet_profiles_microchip_number_digits
        CHECK (microchip_number IS NULL OR microchip_number ~ '^[0-9]{15}$'),
    ADD CONSTRAINT ck_pet_profiles_weight_positive
        CHECK (weight_grams IS NULL OR weight_grams > 0),
    ADD CONSTRAINT ck_pet_profiles_neuter_status
        CHECK (neuter_status IN ('unknown', 'intact', 'neutered')),
    ADD CONSTRAINT ck_pet_profiles_background_media_kind
        CHECK (background_media_kind IS NULL OR background_media_kind IN ('image', 'video'));

CREATE INDEX IF NOT EXISTS idx_pet_profiles_profile_number
    ON pet_profiles(profile_number);

CREATE INDEX IF NOT EXISTS idx_pet_profiles_owner_active
    ON pet_profiles(owner_user_id, created_at)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_pet_profiles_recoverable_until
    ON pet_profiles(recoverable_until)
    WHERE deleted_at IS NOT NULL;

CREATE TABLE IF NOT EXISTS media_assets (
    id uuid PRIMARY KEY,
    uploaded_by_user_id uuid,
    owner_pet_id uuid,
    usage_kind text NOT NULL,
    source_client text,
    original_file_name text,
    mime_type text NOT NULL,
    byte_size bigint NOT NULL,
    sha256_hex text NOT NULL,
    bucket text NOT NULL,
    object_key text NOT NULL,
    status text NOT NULL DEFAULT 'uploaded',
    delete_after timestamptz,
    deleted_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_media_assets_uploaded_by
        FOREIGN KEY (uploaded_by_user_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT fk_media_assets_pet
        FOREIGN KEY (owner_pet_id) REFERENCES pet_profiles(id) ON DELETE SET NULL,
    CONSTRAINT uq_media_assets_object UNIQUE (bucket, object_key),
    CONSTRAINT ck_media_assets_usage_kind
        CHECK (usage_kind IN ('pet.avatar', 'pet.background.image', 'pet.background.video')),
    CONSTRAINT ck_media_assets_status
        CHECK (status IN ('uploaded', 'bound', 'cleanup_pending', 'deleted', 'failed')),
    CONSTRAINT ck_media_assets_byte_size_positive
        CHECK (byte_size > 0)
);

CREATE TABLE IF NOT EXISTS media_derivatives (
    id uuid PRIMARY KEY,
    parent_asset_id uuid NOT NULL,
    derivative_kind text NOT NULL,
    bucket text NOT NULL,
    object_key text NOT NULL,
    mime_type text NOT NULL,
    byte_size bigint NOT NULL,
    sha256_hex text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_media_derivatives_parent
        FOREIGN KEY (parent_asset_id) REFERENCES media_assets(id) ON DELETE CASCADE,
    CONSTRAINT uq_media_derivatives_object UNIQUE (bucket, object_key),
    CONSTRAINT ck_media_derivatives_kind
        CHECK (derivative_kind IN ('thumbnail', 'video_cover_frame', 'theme_color_frame'))
);

CREATE TABLE IF NOT EXISTS media_bindings (
    id uuid PRIMARY KEY,
    asset_id uuid NOT NULL,
    pet_id uuid NOT NULL,
    usage_kind text NOT NULL,
    status text NOT NULL DEFAULT 'active',
    bound_by_user_id uuid,
    bound_at timestamptz NOT NULL DEFAULT now(),
    replaced_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_media_bindings_asset
        FOREIGN KEY (asset_id) REFERENCES media_assets(id) ON DELETE CASCADE,
    CONSTRAINT fk_media_bindings_pet
        FOREIGN KEY (pet_id) REFERENCES pet_profiles(id) ON DELETE CASCADE,
    CONSTRAINT fk_media_bindings_bound_by
        FOREIGN KEY (bound_by_user_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT ck_media_bindings_usage_kind
        CHECK (usage_kind IN ('pet.avatar', 'pet.background.image', 'pet.background.video')),
    CONSTRAINT ck_media_bindings_status
        CHECK (status IN ('active', 'replaced', 'deleted'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_media_bindings_pet_usage_active
    ON media_bindings(pet_id, usage_kind)
    WHERE status = 'active';

CREATE TABLE IF NOT EXISTS media_cleanup_jobs (
    id uuid PRIMARY KEY,
    asset_id uuid NOT NULL,
    status text NOT NULL DEFAULT 'queued',
    run_after timestamptz NOT NULL,
    attempts integer NOT NULL DEFAULT 0,
    last_error text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_media_cleanup_jobs_asset
        FOREIGN KEY (asset_id) REFERENCES media_assets(id) ON DELETE CASCADE,
    CONSTRAINT ck_media_cleanup_jobs_status
        CHECK (status IN ('queued', 'running', 'succeeded', 'failed'))
);

CREATE TABLE IF NOT EXISTS media_audit_events (
    id uuid PRIMARY KEY,
    asset_id uuid,
    pet_id uuid,
    actor_user_id uuid,
    event_kind text NOT NULL,
    event_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_media_audit_events_asset
        FOREIGN KEY (asset_id) REFERENCES media_assets(id) ON DELETE SET NULL,
    CONSTRAINT fk_media_audit_events_pet
        FOREIGN KEY (pet_id) REFERENCES pet_profiles(id) ON DELETE SET NULL,
    CONSTRAINT fk_media_audit_events_actor
        FOREIGN KEY (actor_user_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT ck_media_audit_events_kind
        CHECK (event_kind IN ('uploaded', 'bound', 'replaced', 'cleanup_queued', 'deleted', 'failed'))
);
