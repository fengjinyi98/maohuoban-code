//! factory LLM Provider 装配工厂
//! 核心职责：
//! - 将运营配置转换为具体厂商 Provider 实例
//! - 统一处理未配置 Provider 的降级行为
//! - 隔离根产品 crate 与具体厂商实现

use std::sync::Arc;

use maohuoban_ai_application::ai::ports::{DisabledLlmProvider, LlmProvider};

use super::{
    DeepSeekLlmProvider, LlmProviderRegistryConfig, LlmProviderRuntimeConfig,
    OpenAiCompatibleLlmProvider,
};

/// build_llm_provider_from_registry_config 从注册表构建 LLM Provider
/// 核心职责：
/// - 选择启用的默认 Provider 配置
/// - 根据厂商 kind 装配具体 Provider
#[must_use]
pub fn build_llm_provider_from_registry_config(
    config: &LlmProviderRegistryConfig,
) -> Arc<dyn LlmProvider> {
    match config.active_runtime_provider_config() {
        Some(runtime_config) => build_llm_provider_from_runtime_config(runtime_config),
        None => Arc::new(DisabledLlmProvider),
    }
}

/// build_llm_provider_from_runtime_config 从运行时配置构建 Provider
/// 核心职责：
/// - 封装厂商 Provider 构造分支
/// - 让新增厂商时只扩展 provider 层
#[must_use]
pub fn build_llm_provider_from_runtime_config(
    config: LlmProviderRuntimeConfig,
) -> Arc<dyn LlmProvider> {
    match config {
        LlmProviderRuntimeConfig::OpenAiCompatible(config) => {
            Arc::new(OpenAiCompatibleLlmProvider::new(config))
        }
        LlmProviderRuntimeConfig::DeepSeek(config) => Arc::new(DeepSeekLlmProvider::new(config)),
    }
}
