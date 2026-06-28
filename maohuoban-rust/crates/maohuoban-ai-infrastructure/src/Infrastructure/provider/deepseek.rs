//! deepseek DeepSeek 厂商 Provider
//! 核心职责：
//! - 封装 DeepSeek 的默认模型调用策略
//! - 复用 OpenAI 兼容协议客户端完成 HTTP 调用
//! - 为后续 DeepSeek 专属 JSON、工具调用差异预留入口

use std::fmt;
use std::future::Future;
use std::pin::Pin;

use futures_util::stream::BoxStream;
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_domain::ai::{AiResult, LlmChatRequest, LlmChatResponse, LlmStreamEvent};
use serde_json::Value;

use super::config::OpenAiCompatibleConfig;
use super::openai_compatible::OpenAiCompatibleLlmProvider;

const DEEPSEEK_DEFAULT_MAX_OUTPUT_TOKENS: u32 = 4096;

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
    /// - 注入 DeepSeek JSON Output 默认响应格式
    /// - 设置足够的默认输出 token，降低 JSON 截断概率
    #[must_use]
    pub fn into_openai_compatible_config(self) -> OpenAiCompatibleConfig {
        OpenAiCompatibleConfig {
            base_url: self.base_url,
            api_key: self.api_key,
            model: self.model,
            timeout_secs: self.timeout_secs,
            temperature: self.temperature,
            max_output_tokens: Some(
                self.max_output_tokens
                    .unwrap_or(DEEPSEEK_DEFAULT_MAX_OUTPUT_TOKENS),
            ),
            response_format: Some(
                self.response_format
                    .unwrap_or_else(|| serde_json::json!({ "type": "json_object" })),
            ),
        }
    }
}

/// DeepSeekLlmProvider DeepSeek 厂商 Provider
/// 核心职责：
/// - 对外实现统一 LlmProvider 端口
/// - 内部委托 OpenAI 兼容协议客户端执行 HTTP 调用
pub struct DeepSeekLlmProvider {
    inner: OpenAiCompatibleLlmProvider,
}

impl DeepSeekLlmProvider {
    /// new 构造 DeepSeek Provider
    #[must_use]
    pub fn new(config: DeepSeekConfig) -> Self {
        Self {
            inner: OpenAiCompatibleLlmProvider::new(config.into_openai_compatible_config()),
        }
    }
}

impl LlmProvider for DeepSeekLlmProvider {
    fn complete<'a>(
        &'a self,
        request: &'a LlmChatRequest,
    ) -> Pin<Box<dyn Future<Output = AiResult<LlmChatResponse>> + Send + 'a>> {
        self.inner.complete(request)
    }

    fn stream<'a>(
        &'a self,
        request: &'a LlmChatRequest,
    ) -> BoxStream<'a, AiResult<LlmStreamEvent>> {
        self.inner.stream(request)
    }
}
