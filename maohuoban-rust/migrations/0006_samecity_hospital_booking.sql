CREATE TABLE IF NOT EXISTS samecity_hospitals (
    id uuid PRIMARY KEY,
    name text NOT NULL,
    city text NOT NULL,
    district text,
    address text NOT NULL,
    phone text,
    service_tags text[] NOT NULL DEFAULT ARRAY[]::text[],
    verification_status text NOT NULL DEFAULT 'pending',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_samecity_hospitals_verification_status
        CHECK (verification_status IN ('pending', 'verified', 'rejected', 'suspended'))
);

CREATE INDEX IF NOT EXISTS idx_samecity_hospitals_city_status
    ON samecity_hospitals(city, verification_status);

CREATE TABLE IF NOT EXISTS samecity_hospital_appointments (
    id uuid PRIMARY KEY,
    owner_user_id uuid NOT NULL,
    pet_id uuid,
    hospital_id uuid NOT NULL,
    scheduled_at timestamptz NOT NULL,
    reason text NOT NULL,
    note text,
    status text NOT NULL DEFAULT 'pending',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_samecity_hospital_appointments_owner_user
        FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_samecity_hospital_appointments_pet
        FOREIGN KEY (pet_id) REFERENCES pet_profiles(id) ON DELETE SET NULL,
    CONSTRAINT fk_samecity_hospital_appointments_hospital
        FOREIGN KEY (hospital_id) REFERENCES samecity_hospitals(id) ON DELETE RESTRICT,
    CONSTRAINT ck_samecity_hospital_appointments_status
        CHECK (status IN ('pending', 'confirmed', 'cancelled', 'completed'))
);

CREATE INDEX IF NOT EXISTS idx_samecity_hospital_appointments_owner
    ON samecity_hospital_appointments(owner_user_id, scheduled_at DESC);

CREATE INDEX IF NOT EXISTS idx_samecity_hospital_appointments_pet
    ON samecity_hospital_appointments(pet_id, scheduled_at DESC)
    WHERE pet_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_samecity_hospital_appointments_hospital
    ON samecity_hospital_appointments(hospital_id, scheduled_at DESC);

INSERT INTO samecity_hospitals (
    id,
    name,
    city,
    district,
    address,
    phone,
    service_tags,
    verification_status
)
VALUES
    (
        '7a5af99c-1e4f-4715-9498-4bcae4f0f101',
        '瑞派宠物医院高新院区',
        '成都',
        '高新区',
        '成都市高新区天府大道中段 88 号',
        '028-88880001',
        ARRAY['体检', '疫苗', '复诊']::text[],
        'verified'
    ),
    (
        '36bf85af-3c54-4f0f-8354-2893a8c328a2',
        '安心动物医院锦江院区',
        '成都',
        '锦江区',
        '成都市锦江区东大街 66 号',
        '028-88880002',
        ARRAY['体检', '影像', '住院']::text[],
        'verified'
    )
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    city = EXCLUDED.city,
    district = EXCLUDED.district,
    address = EXCLUDED.address,
    phone = EXCLUDED.phone,
    service_tags = EXCLUDED.service_tags,
    verification_status = EXCLUDED.verification_status,
    updated_at = now();
