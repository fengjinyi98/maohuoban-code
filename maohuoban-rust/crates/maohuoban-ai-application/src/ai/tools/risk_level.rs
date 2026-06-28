/// AiToolRiskLevel 工具风险等级
/// 核心职责：
/// - 标记工具执行风险，供 PolicyGuard 裁决
/// - 区分低风险只读能力和高风险写入能力
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AiToolRiskLevel {
    Low,
    Medium,
    High,
    Critical,
}
