use serde::{Deserialize, Serialize};

/// ToolFailure 结构化工具失败
/// 核心职责：
/// - 统一表达工具调用失败的结构化信息
/// - 前端只展示 safe_user_message，不泄露 internal_reason
/// - 模型可根据 recoverable 决定追问或换工具
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ToolFailure {
    /// 稳定错误码，用于日志和监控
    pub error_code: String,
    /// 是否可恢复：模型可重试或换工具
    pub recoverable: bool,
    /// 安全用户文案：前端直接展示
    pub safe_user_message: String,
    /// 内部原因：仅用于日志和诊断，不返回给用户
    #[serde(default, skip_serializing_if = "String::is_empty")]
    pub internal_reason: String,
}

impl ToolFailure {
    /// new 构造结构化工具失败
    #[must_use]
    pub fn new(
        error_code: &str,
        recoverable: bool,
        safe_user_message: &str,
        internal_reason: &str,
    ) -> Self {
        Self {
            error_code: error_code.to_owned(),
            recoverable,
            safe_user_message: safe_user_message.to_owned(),
            internal_reason: internal_reason.to_owned(),
        }
    }
}
