//! LlmProviderOperationalConfig LLM Provider 运营配置
//! 核心职责：
//! - 承载管理后台需要读写的 Provider 元数据和运行参数
//! - 将密钥限制在后端配置和运行时装配层使用

use std::fmt;

use serde::{Deserialize, Serialize};
use serde_json::Value;

use super::helpers::non_empty_or_default;
use super::openai_compatible::OpenAiCompatibleConfig;
use super::provider_kind::LlmProviderKind;
use super::runtime_config::LlmProviderRuntimeConfig;
use crate::provider::DeepSeekConfig;

#[derive(Clone, Deserialize, PartialEq, Serialize)]
pub struct LlmProviderOperationalConfig {
    pub id: String,
    pub display_name: String,
    pub kind: LlmProviderKind,
    pub enabled: bool,
    pub is_default: bool,
    pub base_url: String,
    #[serde(skip_serializing)]
    pub api_key: String,
    pub model: String,
    pub timeout_secs: u64,
    pub temperature: f32,
    pub max_output_tokens: Option<u32>,
    pub response_format: Option<Value>,
}

impl fmt::Debug for LlmProviderOperationalConfig {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("LlmProviderOperationalConfig")
            .field("id", &self.id)
            .field("display_name", &self.display_name)
            .field("kind", &self.kind)
            .field("enabled", &self.enabled)
            .field("is_default", &self.is_default)
            .field("base_url", &self.base_url)
            .field("api_key", &"<redacted>")
            .field("model", &self.model)
            .field("timeout_secs", &self.timeout_secs)
            .field("temperature", &self.temperature)
            .field("max_output_tokens", &self.max_output_tokens)
            .field("response_format", &self.response_format)
            .finish()
    }
}

impl LlmProviderOperationalConfig {
    #[must_use]
    pub fn from_openai_compatible_config(
        id: impl Into<String>,
        display_name: impl Into<String>,
        enabled: bool,
        is_default: bool,
        config: OpenAiCompatibleConfig,
    ) -> Self {
        let id = id.into();
        let display_name = display_name.into();
        Self {
            id: non_empty_or_default(&id, "openai-compatible"),
            display_name: non_empty_or_default(&display_name, "OpenAI Compatible"),
            kind: LlmProviderKind::OpenAiCompatible,
            enabled,
            is_default,
            base_url: config.base_url,
            api_key: config.api_key,
            model: config.model,
            timeout_secs: config.timeout_secs,
            temperature: config.temperature,
            max_output_tokens: config.max_output_tokens,
            response_format: config.response_format,
        }
    }

    #[must_use]
    pub fn from_deepseek_config(
        id: impl Into<String>,
        display_name: impl Into<String>,
        enabled: bool,
        is_default: bool,
        config: DeepSeekConfig,
    ) -> Self {
        let id = id.into();
        let display_name = display_name.into();
        Self {
            id: non_empty_or_default(&id, "deepseek"),
            display_name: non_empty_or_default(&display_name, "DeepSeek"),
            kind: LlmProviderKind::DeepSeek,
            enabled,
            is_default,
            base_url: config.base_url,
            api_key: config.api_key,
            model: config.model,
            timeout_secs: config.timeout_secs,
            temperature: config.temperature,
            max_output_tokens: config.max_output_tokens,
            response_format: config.response_format,
        }
    }

    #[must_use]
    pub fn to_openai_compatible_config(&self) -> Option<OpenAiCompatibleConfig> {
        if self.kind != LlmProviderKind::OpenAiCompatible || !self.enabled {
            return None;
        }
        Some(self.to_openai_compatible_protocol_config())
    }

    #[must_use]
    pub fn to_runtime_provider_config(&self) -> Option<LlmProviderRuntimeConfig> {
        if !self.enabled {
            return None;
        }
        let config = self.to_openai_compatible_protocol_config();
        Some(match self.kind {
            LlmProviderKind::OpenAiCompatible => LlmProviderRuntimeConfig::OpenAiCompatible(config),
            LlmProviderKind::DeepSeek => LlmProviderRuntimeConfig::DeepSeek(
                DeepSeekConfig::from_openai_compatible_config(config),
            ),
        })
    }

    fn to_openai_compatible_protocol_config(&self) -> OpenAiCompatibleConfig {
        OpenAiCompatibleConfig {
            base_url: self.base_url.clone(),
            api_key: self.api_key.clone(),
            model: self.model.clone(),
            timeout_secs: self.timeout_secs,
            temperature: self.temperature,
            max_output_tokens: self.max_output_tokens,
            response_format: self.response_format.clone(),
        }
    }
}
