use super::AiToolRiskLevel;

/// AiToolMetadata 工具风险与执行约束元数据
/// 核心职责：
/// - 声明工具 scope、只读性、并发安全性和风险等级
/// - 声明确认需求和领域标签，支撑策略裁决与工具发现
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AiToolMetadata {
    pub scope: String,
    pub read_only: bool,
    pub concurrency_safe: bool,
    pub risk_level: AiToolRiskLevel,
    pub requires_confirmation: bool,
    pub domain_tags: Vec<String>,
}
