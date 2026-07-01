use maohuoban_ai_domain::ai::AgentTurnId;
use serde_json::{Value, json};
use uuid::Uuid;

use super::{StepKind, StepPlan};

/// PlanningDiagnosticsSnapshot 规划诊断快照
/// 核心职责：
/// - 固定 task、step、transition、replan 和 policy 诊断字段
/// - 强制携带 session_id、turn_id 和 message_id 三个关联键
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlanningDiagnosticsSnapshot {
    session_id: Uuid,
    turn_id: AgentTurnId,
    message_id: Uuid,
    task_type: &'static str,
    step_list: Vec<&'static str>,
    current_step: Option<&'static str>,
    step_transition: Option<String>,
    replan_reason: Option<String>,
    terminal_step: &'static str,
    policy_decision: &'static str,
}

impl PlanningDiagnosticsSnapshot {
    /// new 基于 StepPlan 创建规划诊断快照
    #[must_use]
    pub fn new(session_id: Uuid, turn_id: AgentTurnId, message_id: Uuid, plan: &StepPlan) -> Self {
        Self {
            session_id,
            turn_id,
            message_id,
            task_type: plan.task_type().as_str(),
            step_list: plan.step_kinds().iter().map(|step| step.as_str()).collect(),
            current_step: plan.step_kinds().first().map(|step| step.as_str()),
            step_transition: None,
            replan_reason: None,
            terminal_step: plan.terminal_step().as_str(),
            policy_decision: plan.policy().policy_decision(),
        }
    }

    /// with_current_step 设置当前 step
    #[must_use]
    pub fn with_current_step(mut self, step: StepKind) -> Self {
        self.current_step = Some(step.as_str());
        self
    }

    /// with_step_transition 设置 step 迁移
    #[must_use]
    pub fn with_step_transition(mut self, from: StepKind, to: StepKind) -> Self {
        self.step_transition = Some(format!("{}->{}", from.as_str(), to.as_str()));
        self
    }

    /// with_replan_reason 设置重规划原因
    #[must_use]
    pub fn with_replan_reason(mut self, reason: impl Into<String>) -> Self {
        self.replan_reason = Some(reason.into());
        self
    }

    /// to_metadata_entries 返回 diagnostics 可直接记录的字段
    #[must_use]
    pub fn to_metadata_entries(&self) -> Vec<(&'static str, Value)> {
        vec![
            ("session_id", json!(self.session_id)),
            ("turn_id", json!(self.turn_id.as_uuid())),
            ("message_id", json!(self.message_id)),
            ("task_type", json!(self.task_type)),
            ("step_list", json!(self.step_list)),
            ("current_step", json!(self.current_step.unwrap_or_default())),
            (
                "step_transition",
                json!(self.step_transition.clone().unwrap_or_default()),
            ),
            (
                "replan_reason",
                json!(self.replan_reason.clone().unwrap_or_default()),
            ),
            ("terminal_step", json!(self.terminal_step)),
            ("policy_decision", json!(self.policy_decision)),
        ]
    }

    /// to_metadata 返回 JSON object，供合同测试和诊断断言使用
    #[must_use]
    pub fn to_metadata(&self) -> Value {
        let mut object = serde_json::Map::new();
        for (key, value) in self.to_metadata_entries() {
            object.insert(key.to_owned(), value);
        }
        Value::Object(object)
    }
}
