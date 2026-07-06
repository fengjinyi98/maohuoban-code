-- 0051_ai_tool_access_payload_audit
-- 核心职责：
-- - 保存运行时工具调用的模型入参摘要和工具响应摘要
-- - 支撑 Agent planning 决策审计，不改变工具授权和执行结果

ALTER TABLE ai_tool_access_logs
    ADD COLUMN IF NOT EXISTS request_payload JSONB,
    ADD COLUMN IF NOT EXISTS response_payload JSONB;

ALTER TABLE agent_proactive_followups
    ADD COLUMN IF NOT EXISTS planning_decision JSONB;
