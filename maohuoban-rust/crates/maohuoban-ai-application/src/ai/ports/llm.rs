use std::future::Future;
use std::pin::Pin;
use std::sync::Arc;

use futures_util::stream::{BoxStream, StreamExt};
use maohuoban_ai_domain::ai::{
    AiError, AiResult, LlmChatRequest, LlmChatResponse, LlmStreamEvent, ProviderError,
    ProviderErrorCategory,
};

/// LlmProvider LLM Provider 端口
/// 核心职责：
/// - 屏蔽厂商差异，application 只依赖该 trait
/// - 完整响应和流式响应都通过该端口获取
pub trait LlmProvider: Send + Sync {
    /// complete 非流式完整响应
    fn complete<'a>(
        &'a self,
        request: &'a LlmChatRequest,
    ) -> Pin<Box<dyn Future<Output = AiResult<LlmChatResponse>> + Send + 'a>>;

    /// stream 流式响应，返回稳定 LlmStreamEvent 流
    fn stream<'a>(&'a self, request: &'a LlmChatRequest)
    -> BoxStream<'a, AiResult<LlmStreamEvent>>;
}

/// FakeLlmProvider 测试用内存 Provider
/// 核心职责：
/// - 返回可配置的固定响应或 delta 序列
/// - 不依赖任何网络或具体厂商
#[derive(Clone)]
pub struct FakeLlmProvider {
    response: Arc<LlmChatResponse>,
    stream_events: Arc<Vec<LlmStreamEvent>>,
}

impl FakeLlmProvider {
    /// new 构造固定响应 fake provider
    #[must_use]
    pub fn new(response: LlmChatResponse, stream_events: Vec<LlmStreamEvent>) -> Self {
        Self {
            response: Arc::new(response),
            stream_events: Arc::new(stream_events),
        }
    }
}

impl LlmProvider for FakeLlmProvider {
    fn complete<'a>(
        &'a self,
        _request: &'a LlmChatRequest,
    ) -> Pin<Box<dyn Future<Output = AiResult<LlmChatResponse>> + Send + 'a>> {
        let response = self.response.clone();
        Box::pin(async move { Ok((*response).clone()) })
    }

    fn stream<'a>(
        &'a self,
        _request: &'a LlmChatRequest,
    ) -> BoxStream<'a, AiResult<LlmStreamEvent>> {
        let events: Vec<AiResult<LlmStreamEvent>> =
            self.stream_events.iter().cloned().map(Ok).collect();
        futures_util::stream::iter(events).boxed()
    }
}

/// DisabledLlmProvider 未配置 Provider 占位
/// 核心职责：
/// - 本地缺少 API key 时服务仍可启动，调用时返回 provider_not_configured
#[derive(Clone, Copy)]
pub struct DisabledLlmProvider;

impl LlmProvider for DisabledLlmProvider {
    fn complete<'a>(
        &'a self,
        _request: &'a LlmChatRequest,
    ) -> Pin<Box<dyn Future<Output = AiResult<LlmChatResponse>> + Send + 'a>> {
        Box::pin(async {
            Err(AiError::Provider(ProviderError::new(
                ProviderErrorCategory::NotConfigured,
                "provider is not configured",
            )))
        })
    }

    fn stream<'a>(
        &'a self,
        _request: &'a LlmChatRequest,
    ) -> BoxStream<'a, AiResult<LlmStreamEvent>> {
        futures_util::stream::once(async {
            Err(AiError::Provider(ProviderError::new(
                ProviderErrorCategory::NotConfigured,
                "provider is not configured",
            )))
        })
        .boxed()
    }
}
