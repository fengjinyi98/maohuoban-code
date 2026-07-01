//! LlmProviderRuntimeConfig LLM Provider 运行时配置
//! 核心职责：
//! - 将运营配置中的 kind 分发为具体厂商 Provider 配置
//! - 让装配层只依赖该枚举选择 Provider 实现

use super::openai_compatible::OpenAiCompatibleConfig;
use crate::provider::DeepSeekConfig;

/// LlmProviderRuntimeConfig LLM Provider 运行时配置
#[derive(Clone, PartialEq)]
pub enum LlmProviderRuntimeConfig {
    OpenAiCompatible(OpenAiCompatibleConfig),
    DeepSeek(DeepSeekConfig),
}
