use maohuoban_ai_domain::ai::{ToolFactSchema, ToolProgressText, Toolset};

use super::AiToolRiskLevel;

/// ToolDefinitionInfo 工具定义信息
/// 核心职责：
/// - 用于 list_definitions 返回注册工具的基础信息和风险 metadata
/// - 透传 toolset 分组、进度文案和事实输出 schema
#[allow(clippy::struct_excessive_bools)]
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ToolDefinitionInfo {
    pub name: String,
    pub description: String,
    pub parameters: serde_json::Value,
    pub scope: String,
    pub declared_requires_confirmation: bool,
    pub read_only: bool,
    pub concurrency_safe: bool,
    pub risk_level: AiToolRiskLevel,
    pub requires_confirmation: bool,
    pub domain_tags: Vec<String>,
    pub toolset: Toolset,
    pub progress_text: ToolProgressText,
    pub result_fact_schema: Option<ToolFactSchema>,
}
