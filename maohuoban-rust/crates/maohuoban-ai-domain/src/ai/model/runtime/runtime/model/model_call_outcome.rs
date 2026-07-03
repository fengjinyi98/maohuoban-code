use serde::{Deserialize, Serialize};

use super::super::provider_error::ProviderErrorCategory;
use super::super::{LlmFinishReason, LlmUsage};

/// ModelCallOutcome 模型调用结果
/// 核心职责：
/// - 在 CallModel step 内表达成功完成或 Provider 失败
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "status", rename_all = "snake_case")]
pub enum ModelCallOutcome {
    Finished {
        finish_reason: LlmFinishReason,
        usage: LlmUsage,
        provider: String,
        model: String,
    },
    ProviderError {
        category: ProviderErrorCategory,
        retryable: bool,
        error_code: String,
    },
}
