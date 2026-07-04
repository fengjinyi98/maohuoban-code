-- 0045_attention_hint_pantry_item_route
-- 核心职责：
-- - 允许首页轻提示直接路由到储物柜物品详情
-- - 支撑库存快消耗完的低心智确认闭环

ALTER TABLE attention_hints
    DROP CONSTRAINT IF EXISTS ck_attention_hints_route_kind;

ALTER TABLE attention_hints
    ADD CONSTRAINT ck_attention_hints_route_kind
        CHECK (route_kind IN (
            'abnormal_detail', 'confirmation_task', 'reminder_detail',
            'preventive_care_detail', 'weight_record', 'ai_chat', 'pantry_item_detail'
        ));
