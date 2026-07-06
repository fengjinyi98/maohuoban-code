-- 0053_agent_abnormal_recovery_confirmation
-- 核心职责：
-- - 允许 Agent 在用户授权前创建异常恢复候选确认任务
-- - 保持真实 abnormal_recovery 写入仍由确认授权流提交

ALTER TABLE agent_confirmation_tasks
    DROP CONSTRAINT IF EXISTS ck_agent_confirmation_tasks_task_kind;

ALTER TABLE agent_confirmation_tasks
    ADD CONSTRAINT ck_agent_confirmation_tasks_task_kind
        CHECK (task_kind IN (
            'diet_change_confirmation',
            'symptom_followup',
            'abnormal_symptom_creation',
            'abnormal_recovery',
            'risk_context_confirmation'
        ));
