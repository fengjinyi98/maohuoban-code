-- 0019_pet_external_identifier_conflicts
-- 核心职责：
-- - 为外部标识补充重复防护索引
-- - 将既有冲突芯片收敛为 disputed，保留 pet_id 身份存在性

WITH duplicated_active_pet_type AS (
    SELECT id,
           row_number() OVER (
               PARTITION BY pet_id, identifier_type
               ORDER BY created_at DESC, id DESC
           ) AS row_num
    FROM pet_external_identifiers
    WHERE status = 'active'
)
UPDATE pet_external_identifiers identifiers
SET status = 'disputed', updated_at = now()
FROM duplicated_active_pet_type duplicated
WHERE identifiers.id = duplicated.id
  AND duplicated.row_num > 1;

WITH conflicting_values AS (
    SELECT identifier_type, identifier_value
    FROM pet_external_identifiers
    WHERE status = 'active'
    GROUP BY identifier_type, identifier_value
    HAVING COUNT(DISTINCT pet_id) > 1
)
UPDATE pet_external_identifiers identifiers
SET status = 'disputed', updated_at = now()
FROM conflicting_values conflicts
WHERE identifiers.identifier_type = conflicts.identifier_type
  AND identifiers.identifier_value = conflicts.identifier_value
  AND identifiers.status = 'active';

CREATE UNIQUE INDEX IF NOT EXISTS uq_pet_external_identifiers_pet_type_active
    ON pet_external_identifiers(pet_id, identifier_type)
    WHERE status = 'active';

CREATE UNIQUE INDEX IF NOT EXISTS uq_pet_external_identifiers_pet_type_value_non_removed
    ON pet_external_identifiers(pet_id, identifier_type, identifier_value)
    WHERE status <> 'removed';
