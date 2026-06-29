use maohuoban_ai_domain::ai::{ToolFactSchema, ToolProgressText, Toolset};

use super::AiToolRiskLevel;

/// AiToolMetadata 工具风险与执行约束元数据
/// 核心职责：
/// - 声明工具 scope、只读性、并发安全性和风险等级
/// - 声明确认需求和领域标签，支撑策略裁决与工具发现
/// - 携带 toolset 分组、进度文案和事实输出 schema
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AiToolMetadata {
    pub scope: String,
    pub read_only: bool,
    pub concurrency_safe: bool,
    pub risk_level: AiToolRiskLevel,
    pub requires_confirmation: bool,
    pub domain_tags: Vec<String>,
    /// 工具所属分组，决定每个 turn 的模型工具清单
    pub toolset: Toolset,
    /// 工具执行进度文案，前端直接使用
    pub progress_text: ToolProgressText,
    /// 工具事实输出 schema，供事实投影层校验
    pub result_fact_schema: Option<ToolFactSchema>,
}
