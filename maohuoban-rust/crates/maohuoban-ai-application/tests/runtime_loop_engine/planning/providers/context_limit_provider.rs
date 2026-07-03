use std::sync::{Arc, Mutex};

use futures_util::StreamExt;
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_domain::ai::{
    AiError, LlmChatRequest, LlmChatResponse, LlmFinishReason, LlmStreamEvent, LlmUsage,
    ProviderError, ProviderErrorCategory,
};

/// `ContextLimitProvider` 首次返回上下文超限的测试 provider
/// 核心职责：
/// - 记录每次模型请求
/// - 验证上下文压缩后重试路径
#[derive(Clone)]
pub struct ContextLimitProvider {
    requests: Arc<Mutex<Vec<LlmChatRequest>>>,
    attempts: Arc<Mutex<u32>>,
}

impl ContextLimitProvider {
    pub fn new() -> Self {
        Self {
            requests: Arc::new(Mutex::new(Vec::new())),
            attempts: Arc::new(Mutex::new(0)),
        }
    }

    pub fn take_requests(&self) -> Vec<LlmChatRequest> {
        self.requests.lock().expect("requests").clone()
    }
}

impl LlmProvider for ContextLimitProvider {
    fn complete<'a>(
        &'a self,
        _request: &'a LlmChatRequest,
    ) -> std::pin::Pin<
        Box<
            dyn std::future::Future<Output = maohuoban_ai_domain::ai::AiResult<LlmChatResponse>>
                + Send
                + 'a,
        >,
    > {
        Box::pin(async {
            Err(AiError::Provider(ProviderError::new(
                ProviderErrorCategory::InvalidResponse,
                "maximum context length exceeded",
            )))
        })
    }

    fn stream<'a>(
        &'a self,
        request: &'a LlmChatRequest,
    ) -> futures_util::stream::BoxStream<'a, maohuoban_ai_domain::ai::AiResult<LlmStreamEvent>>
    {
        self.requests
            .lock()
            .expect("requests")
            .push(request.clone());
        let mut attempts = self.attempts.lock().expect("attempts");
        *attempts += 1;
        let events = if *attempts == 1 {
            vec![Err(AiError::Provider(ProviderError::new(
                ProviderErrorCategory::InvalidResponse,
                "maximum context length exceeded",
            )))]
        } else {
            vec![
                Ok(LlmStreamEvent::Delta {
                    content: "压缩上下文后回答。".to_owned(),
                }),
                Ok(LlmStreamEvent::Finish {
                    finish_reason: LlmFinishReason::Stop,
                    usage: LlmUsage::default(),
                }),
            ]
        };
        futures_util::stream::iter(events).boxed()
    }
}
