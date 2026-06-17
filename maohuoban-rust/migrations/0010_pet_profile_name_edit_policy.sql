CREATE TABLE IF NOT EXISTS pet_profile_name_changes (
    id uuid PRIMARY KEY,
    pet_id uuid NOT NULL,
    owner_user_id uuid NOT NULL,
    old_name text NOT NULL,
    new_name text NOT NULL,
    changed_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_pet_profile_name_changes_pet
        FOREIGN KEY (pet_id) REFERENCES pet_profiles(id) ON DELETE CASCADE,
    CONSTRAINT fk_pet_profile_name_changes_owner
        FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_pet_profile_name_changes_pet_changed_at
    ON pet_profile_name_changes(pet_id, changed_at DESC);
