use maohuoban_ai_domain::ai::ProviderErrorCategory;

/// ReplanCause 重试或重规划原因
/// 核心职责：
/// - 将 provider、tool、context 和 guardrail 失败折叠为规划层原因
/// - 支撑 ReplanPolicy 统一裁决 retry / replan / terminal
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ReplanCause {
    ProviderTimeout,
    StreamInterrupted,
    ToolInvalidArguments,
    ToolUnauthorized,
    EvidenceInsufficient,
    ContextLimitExceeded,
    GuardrailHardStop,
}

impl ReplanCause {
    /// from_provider_category 将 Provider 错误分类映射为重规划原因
    #[must_use]
    pub const fn from_provider_category(category: ProviderErrorCategory) -> Option<Self> {
        match category {
            ProviderErrorCategory::Timeout => Some(Self::ProviderTimeout),
            ProviderErrorCategory::StreamInterrupted
            | ProviderErrorCategory::ProviderStreamError => Some(Self::StreamInterrupted),
            _ => None,
        }
    }

    /// as_str 返回冻结原因编码
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::ProviderTimeout => "provider_timeout",
            Self::StreamInterrupted => "stream_interrupted",
            Self::ToolInvalidArguments => "tool_invalid_arguments",
            Self::ToolUnauthorized => "tool_unauthorized",
            Self::EvidenceInsufficient => "evidence_insufficient",
            Self::ContextLimitExceeded => "context_limit_exceeded",
            Self::GuardrailHardStop => "guardrail_hard_stop",
        }
    }
}
