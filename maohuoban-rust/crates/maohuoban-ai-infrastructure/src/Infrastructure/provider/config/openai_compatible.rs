//! OpenAiCompatibleConfig OpenAI 兼容 Provider 配置
//! 核心职责：
//! - 承载 base_url、api_key、model、timeout 等连接参数
//! - api_key 只在 infrastructure 内使用，Debug 输出脱敏

use std::fmt;

use serde_json::Value;

use super::helpers::{required_trimmed, response_format_from_env_value};

/// OpenAiCompatibleConfig OpenAI 兼容 Provider 配置
#[derive(Clone, PartialEq)]
pub struct OpenAiCompatibleConfig {
    pub base_url: String,
    pub api_key: String,
    pub model: String,
    pub timeout_secs: u64,
    pub temperature: f32,
    pub max_output_tokens: Option<u32>,
    pub response_format: Option<Value>,
}

impl fmt::Debug for OpenAiCompatibleConfig {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("OpenAiCompatibleConfig")
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

impl OpenAiCompatibleConfig {
    /// from_env 读取 OpenAI 兼容 Provider 环境配置
    /// 核心职责：
    /// - 缺少 base_url、api_key 或 model 时返回 None，允许服务降级启动
    #[must_use]
    pub fn from_env() -> Option<Self> {
        Self::from_env_values(
            std::env::var("AI_LLM_BASE_URL").ok().as_deref(),
            std::env::var("AI_LLM_API_KEY").ok().as_deref(),
            std::env::var("AI_LLM_MODEL").ok().as_deref(),
            std::env::var("AI_LLM_TIMEOUT_SECS").ok().as_deref(),
            std::env::var("AI_LLM_TEMPERATURE").ok().as_deref(),
            std::env::var("AI_LLM_MAX_OUTPUT_TOKENS").ok().as_deref(),
            std::env::var("AI_LLM_RESPONSE_FORMAT").ok().as_deref(),
        )
    }

    /// from_env_values 从已读取环境变量值构造 Provider 配置
    /// 核心职责：
    /// - 便于测试配置解析，不在测试中修改进程级环境变量
    /// - 空字符串按缺失处理
    #[must_use]
    pub fn from_env_values(
        base_url: Option<&str>,
        api_key: Option<&str>,
        model: Option<&str>,
        timeout_secs: Option<&str>,
        temperature: Option<&str>,
        max_output_tokens: Option<&str>,
        response_format: Option<&str>,
    ) -> Option<Self> {
        let base_url = required_trimmed(base_url)?;
        let api_key = required_trimmed(api_key)?;
        let model = required_trimmed(model)?;

        Some(Self {
            base_url,
            api_key,
            model,
            timeout_secs: timeout_secs
                .and_then(|value| value.trim().parse::<u64>().ok())
                .unwrap_or(30),
            temperature: temperature
                .and_then(|value| value.trim().parse::<f32>().ok())
                .unwrap_or(0.2),
            max_output_tokens: max_output_tokens.and_then(|value| value.trim().parse().ok()),
            response_format: response_format_from_env_value(response_format),
        })
    }
}
