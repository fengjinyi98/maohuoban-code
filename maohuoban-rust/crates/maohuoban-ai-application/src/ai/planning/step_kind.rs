use serde::{Deserialize, Serialize};

/// StepKind 规划执行步骤类型
/// 核心职责：
/// - 固定轻规划协议中的最小执行单元
/// - 为 runtime phase、diagnostics 和测试提供稳定编码
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum StepKind {
    LoadContext,
    ModelReason,
    ToolRead,
    FinalizeAnswer,
}

impl StepKind {
    /// as_str 返回冻结 step 编码
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::LoadContext => "load_context",
            Self::ModelReason => "model_reason",
            Self::ToolRead => "tool_read",
            Self::FinalizeAnswer => "finalize_answer",
        }
    }
}
