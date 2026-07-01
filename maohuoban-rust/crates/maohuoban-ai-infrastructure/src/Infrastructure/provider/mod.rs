// MHB_STRUCTURE_EXEMPTION: provider mod.rs 是模块聚合与重导出文件，必须位于 provider 目录根
//! provider AI 基础设施 Provider 实现
//! 核心职责：
//! - 实现厂商 LLM Provider 与 OpenAI 兼容协议客户端
//! - 通过 factory 根据运营配置装配具体 Provider
//! - 密钥只在 infrastructure 内读取和使用，不进入 domain/application/日志

pub mod config;
pub mod deepseek;
pub mod factory;
pub mod openai;

pub use config::{
    LlmProviderEnvValues, LlmProviderKind, LlmProviderOperationalConfig, LlmProviderPublicSettings,
    LlmProviderRegistryConfig, LlmProviderRuntimeConfig, OpenAiCompatibleConfig,
};
pub use deepseek::{DeepSeekConfig, DeepSeekLlmProvider};
pub use factory::{
    build_llm_provider_from_registry_config, build_llm_provider_from_runtime_config,
};
pub use openai::OpenAiCompatibleLlmProvider;
pub use openai::sse::{parse_sse_buffer, parse_sse_stream};
