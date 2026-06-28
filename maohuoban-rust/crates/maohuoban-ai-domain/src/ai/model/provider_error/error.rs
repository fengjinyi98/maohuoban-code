use thiserror::Error;

use super::ProviderErrorCategory;

pub const PROVIDER_USER_VISIBLE_FAILURE_MESSAGE: &str = "暂时无法获取回答，请稍后重试。";

/// ProviderError Provider 失败详情
/// 核心职责：
/// - 保留内部错误分类和诊断信息
/// - 对用户统一暴露稳定失败文案
#[derive(Debug, Clone, PartialEq, Eq, Error)]
#[error("provider error {category:?}: {message}")]
pub struct ProviderError {
    category: ProviderErrorCategory,
    message: String,
}

impl ProviderError {
    /// new 构造 Provider 错误
    #[must_use]
    pub fn new(category: ProviderErrorCategory, message: impl Into<String>) -> Self {
        Self {
            category,
            message: message.into(),
        }
    }

    /// category 返回稳定错误分类
    #[must_use]
    pub const fn category(&self) -> ProviderErrorCategory {
        self.category
    }

    /// message 返回内部诊断消息
    #[must_use]
    pub fn message(&self) -> &str {
        &self.message
    }

    /// is_retryable 返回是否适合重试
    #[must_use]
    pub const fn is_retryable(&self) -> bool {
        self.category.is_retryable()
    }

    /// user_visible_message 返回用户可见统一失败文案
    #[must_use]
    pub const fn user_visible_message(&self) -> &'static str {
        PROVIDER_USER_VISIBLE_FAILURE_MESSAGE
    }
}
