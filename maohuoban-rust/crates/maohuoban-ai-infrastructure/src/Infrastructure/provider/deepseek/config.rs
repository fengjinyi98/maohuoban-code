//! config DeepSeek Provider 配置
//! 核心职责：
//! - 承载 DeepSeek 厂商运行参数
//! - 将密钥限制在 infrastructure Provider 内使用

use std::fmt;

use serde_json::Value;

use crate::provider::OpenAiCompatibleConfig;

/// DeepSeekConfig DeepSeek Provider 配置
/// 核心职责：
/// - 承载 DeepSeek 厂商运行参数
/// - 将密钥限制在 infrastructure Provider 内使用
#[derive(Clone, PartialEq)]
pub struct DeepSeekConfig {
    pub base_url: String,
    pub api_key: String,
    pub model: String,
    pub timeout_secs: u64,
    pub temperature: f32,
    pub max_output_tokens: Option<u32>,
    pub response_format: Option<Value>,
}

impl fmt::Debug for DeepSeekConfig {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("DeepSeekConfig")
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

impl DeepSeekConfig {
    /// from_openai_compatible_config 从通用协议配置构造 DeepSeek 配置
    /// 核心职责：
    /// - 复用 base_url、api_key、model 等通用字段
    /// - 保持 DeepSeek 厂商配置类型独立
    #[must_use]
    pub fn from_openai_compatible_config(config: OpenAiCompatibleConfig) -> Self {
        Self {
            base_url: config.base_url,
            api_key: config.api_key,
            model: config.model,
            timeout_secs: config.timeout_secs,
            temperature: config.temperature,
            max_output_tokens: config.max_output_tokens,
            response_format: config.response_format,
        }
    }

    /// into_openai_compatible_config 转换为协议客户端配置
    /// 核心职责：
    /// - 保持 DeepSeek 厂商配置类型独立
    /// - 只传递运营显式配置，不在 Provider 内强制阶段策略
    #[must_use]
    pub fn into_openai_compatible_config(self) -> OpenAiCompatibleConfig {
        OpenAiCompatibleConfig {
            base_url: self.base_url,
            api_key: self.api_key,
            model: self.model,
            timeout_secs: self.timeout_secs,
            temperature: self.temperature,
            max_output_tokens: self.max_output_tokens,
            response_format: self.response_format,
        }
    }
}
