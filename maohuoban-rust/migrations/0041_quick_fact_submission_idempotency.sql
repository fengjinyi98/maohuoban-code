-- 快捷事实提交幂等约束
-- 核心职责：
-- - 防止同一宠物同一次快捷事实提交重复写入事件账本
-- - 保留同一天内不同观察时间点的独立事实记录能力

CREATE UNIQUE INDEX IF NOT EXISTS uq_pet_events_quick_fact_submission
    ON pet_events (
        pet_id,
        (event_payload->>'quick_fact_submission_id')
    )
    WHERE event_subkind = 'quick_fact'
      AND superseded_by_event_id IS NULL
      AND event_payload ? 'quick_fact_submission_id';
