//! LlmProviderPublicSettings LLM Provider 公开配置投影
//! 核心职责：
//! - 为管理后台列表和详情接口提供安全响应形态
//! - 只暴露密钥是否已配置，不返回密钥明文

use serde::Serialize;
use serde_json::Value;

use super::operational_config::LlmProviderOperationalConfig;
use super::provider_kind::LlmProviderKind;

#[derive(Clone, Debug, PartialEq, Serialize)]
pub struct LlmProviderPublicSettings {
    pub id: String,
    pub display_name: String,
    pub kind: LlmProviderKind,
    pub enabled: bool,
    pub is_default: bool,
    pub base_url: String,
    pub model: String,
    pub timeout_secs: u64,
    pub temperature: f32,
    pub max_output_tokens: Option<u32>,
    pub response_format: Option<Value>,
    pub api_key_configured: bool,
}

impl From<&LlmProviderOperationalConfig> for LlmProviderPublicSettings {
    fn from(config: &LlmProviderOperationalConfig) -> Self {
        Self {
            id: config.id.clone(),
            display_name: config.display_name.clone(),
            kind: config.kind,
            enabled: config.enabled,
            is_default: config.is_default,
            base_url: config.base_url.clone(),
            model: config.model.clone(),
            timeout_secs: config.timeout_secs,
            temperature: config.temperature,
            max_output_tokens: config.max_output_tokens,
            response_format: config.response_format.clone(),
            api_key_configured: !config.api_key.trim().is_empty(),
        }
    }
}
