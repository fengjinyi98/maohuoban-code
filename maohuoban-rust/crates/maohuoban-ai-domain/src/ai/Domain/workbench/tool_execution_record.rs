use serde::{Deserialize, Serialize};

use crate::ai::AgentToolStatus;

/// ToolExecutionAudit 工具执行审计记录
/// 核心职责：
/// - 保留工具名、参数 hash、授权结果、风险等级和分组
/// - 不保留原始参数明文，只保留 hash 供审计追踪
/// - 供审计日志和调试使用，不进入用户可见事件
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ToolExecutionAudit {
    pub tool_name: String,
    pub tool_call_id: String,
    pub args_hash: String,
    pub allowed: bool,
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
