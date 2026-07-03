use serde::{Deserialize, Serialize};

use super::super::AgentTurnId;

/// InternalTurnEvent Agent turn 内部事件
/// 核心职责：
/// - 承载模型原始增量、工具规划和 Provider 草稿等内部信号
/// - 作为运行时审计与调试输入，禁止直接投影到 iOS SSE 协议
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "event", rename_all = "snake_case")]
pub enum InternalTurnEvent {
    ModelDelta {
        turn_id: AgentTurnId,
        text: String,
    },
    ToolPlanning {
        turn_id: AgentTurnId,
        tool_call_id: String,
        tool_name: String,
        arguments: String,
    },
    ProviderJsonDraft {
        turn_id: AgentTurnId,
        text: String,
    },
}

impl InternalTurnEvent {
    /// event_name 返回内部事件冻结名称
    #[must_use]
    pub fn event_name(&self) -> &'static str {
        match self {
            Self::ModelDelta { .. } => "model_delta",
            Self::ToolPlanning { .. } => "tool_planning",
            Self::ProviderJsonDraft { .. } => "provider_json_draft",
        }
    }
}
