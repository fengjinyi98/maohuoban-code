use serde::{Deserialize, Serialize};
use serde_json::Value;
use uuid::Uuid;

use crate::ai::AgentToolStatus;

/// ToolExecutionAudit 工具执行审计记录
/// 核心职责：
/// - 保留工具网关统一审计字段和 session/turn/message 关联键
/// - 保留原始参数、策略决策、耗时、事实数量、引用和失败码
/// - 供 diagnostics 与回放使用，不进入用户可见事件
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ToolExecutionAudit {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub session_id: Option<Uuid>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub turn_id: Option<Uuid>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub message_id: Option<Uuid>,
    pub tool_name: String,
    pub args: Value,
    pub policy_decision: String,
    pub duration_ms: u128,
    pub fact_count: usize,
    pub citation_ids: Vec<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub failure_code: Option<String>,
    pub risk_level: String,
    pub toolset: String,
}

/// ToolExecutionTrace 工具执行用户可见轨迹
/// 核心职责：
/// - 只携带展示文案和状态
/// - 不携带 tool_call_id、工具参数、参数 hash、风险标签或授权结果
/// - 供用户可见 SSE 事件使用
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ToolExecutionTrace {
    pub display_text: String,
    pub status: AgentToolStatus,
    pub citation_count: u32,
}
