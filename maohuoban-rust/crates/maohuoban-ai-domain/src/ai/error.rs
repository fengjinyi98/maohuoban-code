use thiserror::Error;

pub type AiResult<T> = Result<T, AiError>;

/// AiError 毛球 Agent 领域错误
/// 核心职责：
/// - 表达 AI 编排、工具调用、Provider 请求和回答校验失败原因
/// - 为 HTTP 层提供稳定错误码映射依据
#[derive(Debug, Error)]
pub enum AiError {
    #[error("invalid ai input: {0}")]
    InvalidInput(String),
    #[error("pet not found or not authorized")]
    PetNotFound,
    #[error("pet access unauthorized")]
    Unauthorized,
    #[error("ai provider not configured")]
    ProviderNotConfigured,
    #[error("ai provider request failed: {0}")]
    ProviderRequestFailed(String),
    #[error("ai provider stream error: {0}")]
    ProviderStreamError(String),
    #[error("ai answer blocked: {0}")]
    AnswerBlocked(String),
    #[error("ai infrastructure error: {0}")]
    Infrastructure(String),
}

impl AiError {
    /// is_retryable 判断错误是否值得前端重试
    /// 核心职责：
    /// - 区分瞬时 Provider 故障与确定性业务拒绝
    pub fn is_retryable(&self) -> bool {
        matches!(
            self,
            Self::ProviderRequestFailed(_) | Self::ProviderStreamError(_) | Self::Infrastructure(_)
        )
    }

    /// stable_code 返回稳定错误码用于 SSE error 事件和日志
    pub fn stable_code(&self) -> &'static str {
        match self {
            Self::InvalidInput(_) => "ai.invalid_input",
            Self::PetNotFound => "ai.pet_not_found",
            Self::Unauthorized => "ai.unauthorized",
            Self::ProviderNotConfigured => "ai.provider_not_configured",
            Self::ProviderRequestFailed(_) => "ai.provider_request_failed",
            Self::ProviderStreamError(_) => "ai.provider_stream_error",
            Self::AnswerBlocked(_) => "ai.answer_blocked",
            Self::Infrastructure(_) => "ai.infrastructure",
        }
    }
}

impl From<serde_json::Error> for AiError {
    fn from(error: serde_json::Error) -> Self {
        Self::Infrastructure(format!("json error: {error}"))
    }
}
