CREATE TABLE IF NOT EXISTS merchant_profiles (
    id uuid PRIMARY KEY,
    owner_user_id uuid NOT NULL,
    merchant_type text NOT NULL,
    name text NOT NULL,
    city text,
    verification_status text NOT NULL DEFAULT 'pending',
    verified_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_merchant_profiles_owner_user
        FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT ck_merchant_profiles_type
        CHECK (merchant_type IN ('pet_store', 'cat_breeder', 'dog_breeder', 'hospital', 'service_provider')),
    CONSTRAINT ck_merchant_profiles_verification_status
        CHECK (verification_status IN ('pending', 'verified', 'rejected', 'suspended'))
);

CREATE INDEX IF NOT EXISTS idx_merchant_profiles_owner
    ON merchant_profiles(owner_user_id);

CREATE INDEX IF NOT EXISTS idx_merchant_profiles_city_status
    ON merchant_profiles(city, verification_status);

CREATE TABLE IF NOT EXISTS pet_profiles (
    id uuid PRIMARY KEY,
    owner_user_id uuid,
    merchant_id uuid,
    name text NOT NULL,
    species text NOT NULL,
    breed text,
    sex text NOT NULL DEFAULT 'unknown',
    birthday date,
    managed_status text NOT NULL DEFAULT 'family',
    source_kind text NOT NULL DEFAULT 'user_created',
    avatar_asset_id uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_pet_profiles_owner_user
        FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT fk_pet_profiles_merchant
        FOREIGN KEY (merchant_id) REFERENCES merchant_profiles(id) ON DELETE SET NULL,
    CONSTRAINT ck_pet_profiles_subject_owner
        CHECK (owner_user_id IS NOT NULL OR merchant_id IS NOT NULL),
    CONSTRAINT ck_pet_profiles_species
        CHECK (species IN ('dog', 'cat', 'other')),
    CONSTRAINT ck_pet_profiles_sex
        CHECK (sex IN ('female', 'male', 'unknown')),
    CONSTRAINT ck_pet_profiles_managed_status
        CHECK (
            managed_status IN (
                'family',
                'available',
                'reserved',
                'sold',
                'retained',
                'fostered',
                'needs_exam',
                'needs_record',
                'inactive'
            )
        ),
    CONSTRAINT ck_pet_profiles_source_kind
        CHECK (source_kind IN ('user_created', 'trade_imported', 'merchant_managed', 'litter_birth'))
);

CREATE INDEX IF NOT EXISTS idx_pet_profiles_owner
    ON pet_profiles(owner_user_id);

CREATE INDEX IF NOT EXISTS idx_pet_profiles_merchant_status
    ON pet_profiles(merchant_id, managed_status);

CREATE INDEX IF NOT EXISTS idx_pet_profiles_species
    ON pet_profiles(species);

CREATE TABLE IF NOT EXISTS litters (
    id uuid PRIMARY KEY,
    merchant_id uuid NOT NULL,
    name text NOT NULL,
    species text NOT NULL,
    sire_pet_id uuid,
    dam_pet_id uuid,
    born_at date NOT NULL,
    born_count integer NOT NULL DEFAULT 0,
    alive_count integer NOT NULL DEFAULT 0,
    status text NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_litters_merchant
        FOREIGN KEY (merchant_id) REFERENCES merchant_profiles(id) ON DELETE CASCADE,
    CONSTRAINT fk_litters_sire_pet
        FOREIGN KEY (sire_pet_id) REFERENCES pet_profiles(id) ON DELETE SET NULL,
    CONSTRAINT fk_litters_dam_pet
        FOREIGN KEY (dam_pet_id) REFERENCES pet_profiles(id) ON DELETE SET NULL,
    CONSTRAINT ck_litters_species
        CHECK (species IN ('dog', 'cat', 'other')),
    CONSTRAINT ck_litters_counts
        CHECK (born_count >= 0 AND alive_count >= 0 AND alive_count <= born_count),
    CONSTRAINT ck_litters_status
        CHECK (status IN ('planned', 'active', 'closed', 'archived'))
);

CREATE INDEX IF NOT EXISTS idx_litters_merchant_born_at
    ON litters(merchant_id, born_at DESC);

CREATE INDEX IF NOT EXISTS idx_litters_parent_pets
    ON litters(sire_pet_id, dam_pet_id);

CREATE TABLE IF NOT EXISTS evidence_snapshots (
    id uuid PRIMARY KEY,
    subject_pet_id uuid,
    subject_litter_id uuid,
    published_by_user_id uuid,
    snapshot_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    attachment_refs jsonb NOT NULL DEFAULT '[]'::jsonb,
    published_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_evidence_snapshots_pet
        FOREIGN KEY (subject_pet_id) REFERENCES pet_profiles(id) ON DELETE SET NULL,
    CONSTRAINT fk_evidence_snapshots_litter
        FOREIGN KEY (subject_litter_id) REFERENCES litters(id) ON DELETE SET NULL,
    CONSTRAINT fk_evidence_snapshots_published_by_user
        FOREIGN KEY (published_by_user_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT ck_evidence_snapshots_subject_present
        CHECK (subject_pet_id IS NOT NULL OR subject_litter_id IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_evidence_snapshots_pet_published_at
    ON evidence_snapshots(subject_pet_id, published_at DESC)
    WHERE subject_pet_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_evidence_snapshots_litter_published_at
    ON evidence_snapshots(subject_litter_id, published_at DESC)
    WHERE subject_litter_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS pet_events (
    id uuid PRIMARY KEY,
    pet_id uuid,
    litter_id uuid,
    event_kind text NOT NULL,
    event_subkind text,
    title text NOT NULL,
    summary text,
    visibility text NOT NULL DEFAULT 'private',
    event_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    occurred_at timestamptz NOT NULL,
    actor_user_id uuid,
    evidence_snapshot_id uuid,
    record_revision integer NOT NULL DEFAULT 1,
    superseded_by_event_id uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_pet_events_pet
        FOREIGN KEY (pet_id) REFERENCES pet_profiles(id) ON DELETE CASCADE,
    CONSTRAINT fk_pet_events_litter
        FOREIGN KEY (litter_id) REFERENCES litters(id) ON DELETE CASCADE,
    CONSTRAINT fk_pet_events_actor_user
        FOREIGN KEY (actor_user_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT fk_pet_events_evidence_snapshot
        FOREIGN KEY (evidence_snapshot_id) REFERENCES evidence_snapshots(id) ON DELETE SET NULL,
    CONSTRAINT fk_pet_events_superseded_by
        FOREIGN KEY (superseded_by_event_id) REFERENCES pet_events(id) ON DELETE SET NULL,
    CONSTRAINT ck_pet_events_subject_present
        CHECK (pet_id IS NOT NULL OR litter_id IS NOT NULL),
    CONSTRAINT ck_pet_events_event_kind
        CHECK (
            event_kind IN (
                'daily',
                'growth',
                'health',
                'hospital',
                'trade',
                'merchant',
                'memorial'
            )
        ),
    CONSTRAINT ck_pet_events_visibility
        CHECK (visibility IN ('private', 'co_caretakers', 'authorized', 'buyer_visible', 'public')),
    CONSTRAINT ck_pet_events_record_revision_positive
        CHECK (record_revision > 0)
);

CREATE INDEX IF NOT EXISTS idx_pet_events_pet_occurred_at
    ON pet_events(pet_id, occurred_at DESC)
    WHERE pet_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_pet_events_litter_occurred_at
    ON pet_events(litter_id, occurred_at DESC)
    WHERE litter_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_pet_events_kind_visibility
    ON pet_events(event_kind, visibility);

CREATE INDEX IF NOT EXISTS idx_pet_events_evidence_snapshot
    ON pet_events(evidence_snapshot_id)
    WHERE evidence_snapshot_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS pet_relationships (
    id uuid PRIMARY KEY,
    subject_pet_id uuid NOT NULL,
    related_pet_id uuid,
    litter_id uuid,
    relationship_kind text NOT NULL,
    source_kind text NOT NULL DEFAULT 'user_recorded',
    evidence_snapshot_id uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_pet_relationships_subject_pet
        FOREIGN KEY (subject_pet_id) REFERENCES pet_profiles(id) ON DELETE CASCADE,
    CONSTRAINT fk_pet_relationships_related_pet
        FOREIGN KEY (related_pet_id) REFERENCES pet_profiles(id) ON DELETE CASCADE,
    CONSTRAINT fk_pet_relationships_litter
        FOREIGN KEY (litter_id) REFERENCES litters(id) ON DELETE CASCADE,
    CONSTRAINT fk_pet_relationships_evidence_snapshot
        FOREIGN KEY (evidence_snapshot_id) REFERENCES evidence_snapshots(id) ON DELETE SET NULL,
    CONSTRAINT ck_pet_relationships_related_subject
        CHECK (related_pet_id IS NOT NULL OR litter_id IS NOT NULL),
    CONSTRAINT ck_pet_relationships_kind
        CHECK (
            relationship_kind IN (
                'sire',
                'dam',
                'same_litter',
                'same_source',
                'transferred_from',
                'co_caretaker',
                'merchant_managed'
            )
        ),
    CONSTRAINT ck_pet_relationships_source_kind
        CHECK (source_kind IN ('user_recorded', 'merchant_recorded', 'system_derived', 'trade_imported'))
);

CREATE INDEX IF NOT EXISTS idx_pet_relationships_subject_kind
    ON pet_relationships(subject_pet_id, relationship_kind);

CREATE INDEX IF NOT EXISTS idx_pet_relationships_related_kind
    ON pet_relationships(related_pet_id, relationship_kind)
    WHERE related_pet_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_pet_relationships_litter
    ON pet_relationships(litter_id)
    WHERE litter_id IS NOT NULL;
