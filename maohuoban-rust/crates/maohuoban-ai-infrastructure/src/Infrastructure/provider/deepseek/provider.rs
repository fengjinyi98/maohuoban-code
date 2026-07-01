//! provider DeepSeek 厂商 Provider
//! 核心职责：
//! - 封装 DeepSeek 的默认模型调用策略与能力画像
//! - 复用 OpenAI 兼容协议客户端完成 HTTP 调用
//! - 通过 ProviderCapability 标记 DeepSeek 与标准 OpenAI 兼容协议的能力差异

use std::future::Future;
use std::pin::Pin;

use futures_util::stream::BoxStream;
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_application::ai::provider_capability::ProviderProfile;
use maohuoban_ai_domain::ai::{AiResult, LlmChatRequest, LlmChatResponse, LlmStreamEvent};

use super::config::DeepSeekConfig;
use crate::provider::OpenAiCompatibleLlmProvider;

/// DeepSeekLlmProvider DeepSeek 厂商 Provider
/// 核心职责：
/// - 对外实现统一 LlmProvider 端口
/// - 内部委托 OpenAI 兼容协议客户端执行 HTTP 调用
/// - 使用 DeepSeek 专属 ProviderCapability 驱动请求裁剪
pub struct DeepSeekLlmProvider {
    inner: OpenAiCompatibleLlmProvider,
}

impl DeepSeekLlmProvider {
    /// new 构造 DeepSeek Provider
    /// 核心职责：
    /// - 使用 DeepSeek 专属能力画像初始化协议客户端
    /// - 标记 JSON Output 不稳定、parallel_tool_calls 默认关闭等已知差异
    #[must_use]
    pub fn new(config: DeepSeekConfig) -> Self {
        let model = config.model.clone();
        let openai_config = config.into_openai_compatible_config();
        let profile = ProviderProfile::deepseek(&model);
        Self {
            inner: OpenAiCompatibleLlmProvider::new_with_profile(openai_config, profile),
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
