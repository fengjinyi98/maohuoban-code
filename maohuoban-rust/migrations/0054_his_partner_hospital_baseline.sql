CREATE TABLE IF NOT EXISTS his_hospital_tenants (
    id uuid PRIMARY KEY,
    name text NOT NULL,
    tenant_tier text NOT NULL DEFAULT 'standard_saas',
    status text NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ck_his_hospital_tenants_tenant_tier
        CHECK (tenant_tier IN ('standard_saas', 'dedicated_tenant')),
    CONSTRAINT ck_his_hospital_tenants_status
        CHECK (status IN ('active', 'suspended', 'archived'))
);

CREATE INDEX IF NOT EXISTS idx_his_hospital_tenants_status
    ON his_hospital_tenants(status);

CREATE TABLE IF NOT EXISTS his_staff_members (
    id uuid PRIMARY KEY,
    tenant_id uuid NOT NULL,
    user_id uuid NOT NULL,
    display_name text NOT NULL,
    role text NOT NULL,
    status text NOT NULL DEFAULT 'active',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_his_staff_members_tenant
        FOREIGN KEY (tenant_id) REFERENCES his_hospital_tenants(id) ON DELETE CASCADE,
    CONSTRAINT fk_his_staff_members_user
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT ck_his_staff_members_role
        CHECK (role IN ('doctor', 'front_desk', 'nurse', 'admin')),
    CONSTRAINT ck_his_staff_members_status
        CHECK (status IN ('active', 'suspended', 'archived')),
    CONSTRAINT uq_his_staff_members_tenant_user
        UNIQUE (tenant_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_his_staff_members_user
    ON his_staff_members(user_id);

CREATE INDEX IF NOT EXISTS idx_his_staff_members_tenant_role
    ON his_staff_members(tenant_id, role)
    WHERE status = 'active';

ALTER TABLE samecity_hospitals
    ADD COLUMN IF NOT EXISTS partnership_status text NOT NULL DEFAULT 'candidate',
    ADD COLUMN IF NOT EXISTS his_enabled boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS his_tenant_id uuid,
    ADD COLUMN IF NOT EXISTS appointment_enabled boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS medical_record_return_enabled boolean NOT NULL DEFAULT false;

ALTER TABLE samecity_hospitals
    ADD CONSTRAINT ck_samecity_hospitals_partnership_status
        CHECK (partnership_status IN ('candidate', 'active', 'suspended'));

ALTER TABLE samecity_hospitals
    ADD CONSTRAINT fk_samecity_hospitals_his_tenant
        FOREIGN KEY (his_tenant_id) REFERENCES his_hospital_tenants(id) ON DELETE SET NULL;

ALTER TABLE samecity_hospitals
    ADD CONSTRAINT ck_samecity_hospitals_his_enabled_requires_tenant
        CHECK (his_enabled = false OR his_tenant_id IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_samecity_hospitals_his_partner_city
    ON samecity_hospitals(city, partnership_status, his_enabled, appointment_enabled)
    WHERE verification_status = 'verified';
