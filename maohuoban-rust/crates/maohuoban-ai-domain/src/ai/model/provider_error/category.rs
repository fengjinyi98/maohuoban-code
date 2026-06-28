use serde::{Deserialize, Serialize};

/// ProviderErrorCategory Provider 错误分类
/// 核心职责：
/// - 提供冻结的 Provider 失败大类
/// - 决定错误是否适合自动重试或前端重试
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ProviderErrorCategory {
    NotConfigured,
    Timeout,
    RateLimited,
    Upstream,
    StreamInterrupted,
    InvalidResponse,
}

impl ProviderErrorCategory {
    /// as_str 返回冻结事件和诊断使用的 snake_case 分类名
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::NotConfigured => "not_configured",
            Self::Timeout => "timeout",
            Self::RateLimited => "rate_limited",
            Self::Upstream => "upstream",
            Self::StreamInterrupted => "stream_interrupted",
            Self::InvalidResponse => "invalid_response",
        }
    }

    /// is_retryable 判断该分类是否属于瞬时 Provider 失败
    #[must_use]
    pub const fn is_retryable(self) -> bool {
        matches!(
            self,
            Self::Timeout | Self::RateLimited | Self::Upstream | Self::StreamInterrupted
        )
    }
}
