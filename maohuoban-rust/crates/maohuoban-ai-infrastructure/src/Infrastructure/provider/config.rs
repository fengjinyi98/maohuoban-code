//! config OpenAI 兼容 Provider 配置
//! 核心职责：
//! - 从环境变量读取 LLM Provider 配置
//! - 缺少必填项时允许服务降级为未配置状态
//! - 对 Debug 输出脱敏 API key

use std::fmt;

/// OpenAiCompatibleConfig OpenAI 兼容 Provider 配置
/// 核心职责：
/// - 承载 base_url、api_key、model、timeout 等配置
/// - api_key 只在 infrastructure 内使用
#[derive(Clone)]
pub struct OpenAiCompatibleConfig {
    pub base_url: String,
    pub api_key: String,
    pub model: String,
    pub timeout_secs: u64,
    pub temperature: f32,
    pub max_output_tokens: Option<u32>,
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
            .finish()
    }
}

impl OpenAiCompatibleConfig {
    /// from_env 读取 OpenAI 兼容 Provider 环境配置
    /// 核心职责：
    /// - 缺少 base_url、api_key 或 model 时返回 None，允许服务降级启动
    /// - 解析 timeout、temperature 和 max output tokens 默认值
    #[must_use]
    pub fn from_env() -> Option<Self> {
        Self::from_env_values(
            std::env::var("AI_LLM_BASE_URL").ok().as_deref(),
            std::env::var("AI_LLM_API_KEY").ok().as_deref(),
            std::env::var("AI_LLM_MODEL").ok().as_deref(),
            std::env::var("AI_LLM_TIMEOUT_SECS").ok().as_deref(),
            std::env::var("AI_LLM_TEMPERATURE").ok().as_deref(),
            std::env::var("AI_LLM_MAX_OUTPUT_TOKENS").ok().as_deref(),
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
        })
    }
}

/// required_trimmed 读取非空配置值
/// 核心职责：
/// - 将缺失或空白字符串统一视为缺配置
fn required_trimmed(value: Option<&str>) -> Option<String> {
    let trimmed = value?.trim();
    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed.to_owned())
    }
}
