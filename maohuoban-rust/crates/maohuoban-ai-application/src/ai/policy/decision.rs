use crate::ai::tools::AiToolConfirmationRequirement;

/// PolicyDecision 工具策略裁决结果
/// 核心职责：
/// - 表达允许、拒绝、转换、确认和终止五类冻结策略结果
/// - 保证拒绝和终止路径不携带私有事实
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum PolicyDecision {
    Allow,
    Deny {
        reason: String,
    },
    Transform {
        args: serde_json::Value,
    },
    RequireConfirmation {
        confirmation: AiToolConfirmationRequirement,
    },
    Terminate {
        reason: String,
    },
}
