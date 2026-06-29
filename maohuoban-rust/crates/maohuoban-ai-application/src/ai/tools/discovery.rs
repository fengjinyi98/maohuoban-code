use maohuoban_ai_domain::ai::Toolset;

use super::ToolDefinitionInfo;

/// ToolGroupSummary 工具发现分组摘要
/// 核心职责：
/// - 按 domain_tags 暴露工具组
/// - 只返回摘要，避免默认展开全部 schema
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ToolGroupSummary {
    pub group: String,
    pub tool_count: usize,
    pub tool_names: Vec<String>,
}

/// ToolGroupSchema 工具发现分组 schema
/// 核心职责：
/// - 按需展开指定工具组的工具定义
/// - 保留工具 metadata 和参数 schema 供模型选择工具
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ToolGroupSchema {
    pub group: String,
    pub tools: Vec<ToolDefinitionInfo>,
}

/// ToolsetGroupSummary toolset 分组摘要
/// 核心职责：
/// - 按 Toolset 枚举分组暴露工具列表
/// - 供 TurnContextBuilder 按 toolset + 权限 + selected pet 组装工具清单
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ToolsetGroupSummary {
    pub toolset: Toolset,
    pub tool_count: usize,
    pub tool_names: Vec<String>,
}
