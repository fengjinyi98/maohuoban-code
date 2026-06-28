use thiserror::Error;

use super::{PROVIDER_USER_VISIBLE_FAILURE_MESSAGE, ProviderError};

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
    #[error("{0}")]
    Provider(ProviderError),
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
            Self::Provider(error) if error.is_retryable()
        ) || matches!(
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
            Self::Provider(error) => match error.category().as_str() {
                "not_configured" => "ai.provider.not_configured",
                "timeout" => "ai.provider.timeout",
                "rate_limited" => "ai.provider.rate_limited",
                "upstream" => "ai.provider.upstream",
                "stream_interrupted" => "ai.provider.stream_interrupted",
                "invalid_response" => "ai.provider.invalid_response",
                _ => "ai.provider",
            },
            Self::ProviderNotConfigured => "ai.provider_not_configured",
            Self::ProviderRequestFailed(_) => "ai.provider_request_failed",
            Self::ProviderStreamError(_) => "ai.provider_stream_error",
            Self::AnswerBlocked(_) => "ai.answer_blocked",
            Self::Infrastructure(_) => "ai.infrastructure",
        }
    }

    /// user_visible_message 返回可安全对外展示的错误文案
    /// 核心职责：
    /// - Provider 详细错误统一折叠为稳定用户文案
    /// - 业务错误继续使用既有稳定表述
    pub fn user_visible_message(&self) -> &'static str {
        match self {
            Self::Provider(error) => error.user_visible_message(),
            Self::ProviderNotConfigured
            | Self::ProviderRequestFailed(_)
            | Self::ProviderStreamError(_) => PROVIDER_USER_VISIBLE_FAILURE_MESSAGE,
            Self::InvalidInput(_) => "请求参数无效。",
            Self::PetNotFound => "宠物档案不存在或无权限。",
            Self::Unauthorized => "无权限访问该资源。",
            Self::AnswerBlocked(_) => "回答内容未通过安全校验。",
            Self::Infrastructure(_) => "AI 服务暂时不可用。",
        }
    }
}

impl From<ProviderError> for AiError {
    fn from(error: ProviderError) -> Self {
        Self::Provider(error)
    }
}

impl From<serde_json::Error> for AiError {
    fn from(error: serde_json::Error) -> Self {
        Self::Infrastructure(format!("json error: {error}"))
    }
}
