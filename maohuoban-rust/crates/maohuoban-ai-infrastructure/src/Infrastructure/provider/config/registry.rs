//! LlmProviderRegistryConfig LLM Provider 配置注册表
//! 核心职责：
//! - 汇总可运营配置的 Provider 列表
//! - 从环境变量读取并选择当前启用的默认 Provider
//! - 生成管理后台可安全消费的公开配置

use super::env_values::LlmProviderEnvValues;
use super::helpers::{bool_from_env_value, required_trimmed};
use super::openai_compatible::OpenAiCompatibleConfig;
use super::operational_config::LlmProviderOperationalConfig;
use super::provider_kind::{LlmProviderKind, provider_kind_from_env_values};
use super::public_settings::LlmProviderPublicSettings;
use crate::provider::DeepSeekConfig;

#[derive(Clone, Debug, Default, PartialEq)]
pub struct LlmProviderRegistryConfig {
    pub providers: Vec<LlmProviderOperationalConfig>,
}

impl LlmProviderRegistryConfig {
    #[must_use]
    pub const fn new(providers: Vec<LlmProviderOperationalConfig>) -> Self {
        Self { providers }
    }

    /// from_env 读取单 Provider 环境配置并映射为运营配置
    #[must_use]
    pub fn from_env() -> Self {
        let provider_id = std::env::var("AI_LLM_PROVIDER_ID").ok();
        let provider_kind = std::env::var("AI_LLM_PROVIDER_KIND").ok();
        let display_name = std::env::var("AI_LLM_PROVIDER_DISPLAY_NAME").ok();
        let enabled = std::env::var("AI_LLM_PROVIDER_ENABLED").ok();
        let is_default = std::env::var("AI_LLM_PROVIDER_IS_DEFAULT").ok();
        let base_url = std::env::var("AI_LLM_BASE_URL").ok();
        let api_key = std::env::var("AI_LLM_API_KEY").ok();
        let model = std::env::var("AI_LLM_MODEL").ok();
        let timeout_secs = std::env::var("AI_LLM_TIMEOUT_SECS").ok();
        let temperature = std::env::var("AI_LLM_TEMPERATURE").ok();
        let max_output_tokens = std::env::var("AI_LLM_MAX_OUTPUT_TOKENS").ok();
        let response_format = std::env::var("AI_LLM_RESPONSE_FORMAT").ok();

        Self::from_env_values(LlmProviderEnvValues {
            provider_kind: provider_kind.as_deref(),
            provider_id: provider_id.as_deref(),
            display_name: display_name.as_deref(),
            enabled: enabled.as_deref(),
            is_default: is_default.as_deref(),
            base_url: base_url.as_deref(),
            api_key: api_key.as_deref(),
            model: model.as_deref(),
            timeout_secs: timeout_secs.as_deref(),
            temperature: temperature.as_deref(),
            max_output_tokens: max_output_tokens.as_deref(),
            response_format: response_format.as_deref(),
        })
    }

    /// from_env_values 从环境变量值构造 Provider 注册表
    #[must_use]
    pub fn from_env_values(values: LlmProviderEnvValues<'_>) -> Self {
        let Some(openai_config) = OpenAiCompatibleConfig::from_env_values(
            values.base_url,
            values.api_key,
            values.model,
            values.timeout_secs,
            values.temperature,
            values.max_output_tokens,
            values.response_format,
        ) else {
            return Self::default();
        };

        let kind = provider_kind_from_env_values(values.provider_kind, values.provider_id);
        let enabled = bool_from_env_value(values.enabled, true);
        let is_default = bool_from_env_value(values.is_default, true);
        let provider = match kind {
            LlmProviderKind::OpenAiCompatible => {
                LlmProviderOperationalConfig::from_openai_compatible_config(
                    required_trimmed(values.provider_id)
                        .unwrap_or_else(|| "env-openai-compatible".to_owned()),
                    required_trimmed(values.display_name)
                        .unwrap_or_else(|| "OpenAI Compatible".to_owned()),
                    enabled,
                    is_default,
                    openai_config,
                )
            }
            LlmProviderKind::DeepSeek => LlmProviderOperationalConfig::from_deepseek_config(
                required_trimmed(values.provider_id).unwrap_or_else(|| "deepseek".to_owned()),
                required_trimmed(values.display_name).unwrap_or_else(|| "DeepSeek".to_owned()),
                enabled,
                is_default,
                DeepSeekConfig::from_openai_compatible_config(openai_config),
            ),
        };

        Self::new(vec![provider])
    }

    #[must_use]
    pub fn active_runtime_provider_config(
        &self,
    ) -> Option<super::runtime_config::LlmProviderRuntimeConfig> {
        self.providers
            .iter()
            .find(|provider| provider.enabled && provider.is_default)
            .and_then(LlmProviderOperationalConfig::to_runtime_provider_config)
    }

    #[must_use]
    pub fn active_openai_compatible_config(&self) -> Option<OpenAiCompatibleConfig> {
        self.providers
            .iter()
            .find(|provider| {
                provider.enabled
                    && provider.is_default
                    && provider.kind == LlmProviderKind::OpenAiCompatible
            })
            .and_then(LlmProviderOperationalConfig::to_openai_compatible_config)
    }

    #[must_use]
    pub fn public_settings(&self) -> Vec<LlmProviderPublicSettings> {
        self.providers
            .iter()
            .map(LlmProviderPublicSettings::from)
            .collect()
    }
}

impl From<OpenAiCompatibleConfig> for LlmProviderRegistryConfig {
    fn from(config: OpenAiCompatibleConfig) -> Self {
        Self::new(vec![
            LlmProviderOperationalConfig::from_openai_compatible_config(
                "default-openai-compatible",
                "OpenAI Compatible",
                true,
                true,
                config,
            ),
        ])
    }
}
