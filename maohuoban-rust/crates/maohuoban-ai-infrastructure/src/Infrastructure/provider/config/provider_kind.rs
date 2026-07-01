//! LlmProviderKind LLM Provider 类型枚举
//! 核心职责：
//! - 标识运营配置中的 Provider 实现类型
//! - 为后续扩展非 OpenAI 兼容 Provider 保留稳定枚举入口

use serde::{Deserialize, Serialize};

/// LlmProviderKind LLM Provider 类型
#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum LlmProviderKind {
    #[serde(rename = "openai_compatible")]
    OpenAiCompatible,
    #[serde(rename = "deepseek")]
    DeepSeek,
}

/// parse_provider_kind 解析 Provider kind 字符串
/// 核心职责：
/// - 支持管理后台和环境变量使用稳定 snake_case 值
/// - 未知值回落给调用方处理
pub(super) fn parse_provider_kind(value: &str) -> Option<LlmProviderKind> {
    match value.trim().to_ascii_lowercase().as_str() {
        "openai_compatible" | "openai-compatible" | "openai" => {
            Some(LlmProviderKind::OpenAiCompatible)
        }
        "deepseek" => Some(LlmProviderKind::DeepSeek),
        _ => None,
    }
}

/// provider_kind_from_env_values 解析环境配置中的 Provider 类型
/// 核心职责：
/// - 优先使用显式 AI_LLM_PROVIDER_KIND
/// - 兼容当前本地配置通过 provider_id=deepseek 推断厂商
pub(super) fn provider_kind_from_env_values(
    provider_kind: Option<&str>,
    provider_id: Option<&str>,
) -> LlmProviderKind {
    if let Some(kind) = provider_kind.and_then(parse_provider_kind) {
        return kind;
    }

    let provider_id = provider_id
        .map(str::trim)
        .unwrap_or_default()
        .to_ascii_lowercase();
    if provider_id == "deepseek" || provider_id.starts_with("deepseek-") {
        return LlmProviderKind::DeepSeek;
    }

    LlmProviderKind::OpenAiCompatible
}
