use std::sync::{Arc, Mutex};

use futures_util::StreamExt;
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_domain::ai::{
    AiError, AiResult, LlmChatRequest, LlmChatResponse, LlmFinishReason, LlmStreamEvent, LlmUsage,
    ProviderError, ProviderErrorCategory,
};

#[derive(Clone)]
pub struct RetryOnceStreamProvider {
    requests: Arc<Mutex<Vec<LlmChatRequest>>>,
    attempts: Arc<Mutex<u32>>,
}

impl RetryOnceStreamProvider {
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

impl LlmProvider for RetryOnceStreamProvider {
    fn complete<'a>(
        &'a self,
        _request: &'a LlmChatRequest,
    ) -> std::pin::Pin<Box<dyn std::future::Future<Output = AiResult<LlmChatResponse>> + Send + 'a>>
    {
        Box::pin(async {
            Err(AiError::Provider(ProviderError::new(
                ProviderErrorCategory::Timeout,
                "complete should not be used",
            )))
        })
    }

    fn stream<'a>(
        &'a self,
        request: &'a LlmChatRequest,
    ) -> futures_util::stream::BoxStream<'a, AiResult<LlmStreamEvent>> {
        self.requests
            .lock()
            .expect("requests")
            .push(request.clone());
        let mut attempts = self.attempts.lock().expect("attempts");
        *attempts += 1;
        let events = if *attempts == 1 {
            vec![Err(AiError::Provider(ProviderError::new(
                ProviderErrorCategory::Timeout,
                "provider timeout",
            )))]
        } else {
            vec![
                Ok(LlmStreamEvent::Delta {
                    content: "先观察精神、食欲和便便频次。".to_owned(),
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
