use std::error::Error;
use std::fmt;

/// ModelRouterError 模型路由错误
/// 核心职责：
/// - 区分未知 label 与 label 未配置具体模型
/// - 提供稳定错误码用于诊断和上层映射
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ModelRouterError {
    UnknownLabel { label: String },
    ModelNotConfigured { label: String },
}

impl ModelRouterError {
    /// stable_code 返回稳定错误码
    #[must_use]
    pub const fn stable_code(&self) -> &'static str {
        match self {
            Self::UnknownLabel { .. } => "ai.model_router.unknown_label",
            Self::ModelNotConfigured { .. } => "ai.model_router.model_not_configured",
        }
    }
}

impl fmt::Display for ModelRouterError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::UnknownLabel { label } => {
                write!(formatter, "unknown model label: {label}")
            }
            Self::ModelNotConfigured { label } => {
                write!(formatter, "model not configured for label: {label}")
            }
        }
    }
}

impl Error for ModelRouterError {}
