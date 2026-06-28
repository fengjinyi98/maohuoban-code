-- AI Agent runtime session event index backfill
-- 核心职责：
-- - 将旧数据回填到稳定的 event_index 顺序
-- - 把 replay 依赖的排序列固定为非空

WITH ordered AS (
    SELECT
        id,
        row_number() OVER (ORDER BY created_at ASC, id ASC) AS rn
    FROM ai_session_events
    WHERE event_index IS NULL
),
offset_base AS (
    SELECT COALESCE(MAX(event_index), 0) AS base
    FROM ai_session_events
)
UPDATE ai_session_events AS events
SET event_index = ordered.rn + offset_base.base
FROM ordered, offset_base
WHERE events.id = ordered.id;

ALTER TABLE ai_session_events
    ALTER COLUMN event_index SET NOT NULL;

SELECT setval(
    pg_get_serial_sequence('ai_session_events', 'event_index'),
    COALESCE((SELECT MAX(event_index) FROM ai_session_events), 1),
    true
);
