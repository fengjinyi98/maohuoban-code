use std::collections::VecDeque;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use futures_util::StreamExt;
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_domain::ai::{AiResult, LlmChatRequest, LlmChatResponse, LlmStreamEvent};

use super::responses::response_to_stream_events;

#[derive(Clone)]
pub struct StreamingScriptedProvider {
    requests: Arc<Mutex<Vec<LlmChatRequest>>>,
    responses: Arc<Mutex<VecDeque<LlmChatResponse>>>,
    delays: Arc<Mutex<VecDeque<Duration>>>,
}

impl StreamingScriptedProvider {
    pub fn new(responses: Vec<LlmChatResponse>) -> Self {
        Self::with_delays(responses, Vec::new())
    }

    pub fn with_delays(responses: Vec<LlmChatResponse>, delays: Vec<Duration>) -> Self {
        Self {
            requests: Arc::new(Mutex::new(Vec::new())),
            responses: Arc::new(Mutex::new(VecDeque::from(responses))),
            delays: Arc::new(Mutex::new(VecDeque::from(delays))),
        }
    }

    pub fn take_requests(&self) -> Vec<LlmChatRequest> {
        self.requests.lock().expect("requests").clone()
    }
}

impl LlmProvider for StreamingScriptedProvider {
    fn complete<'a>(
        &'a self,
        _request: &'a LlmChatRequest,
    ) -> std::pin::Pin<Box<dyn std::future::Future<Output = AiResult<LlmChatResponse>> + Send + 'a>>
    {
        Box::pin(async {
            Err(maohuoban_ai_domain::ai::AiError::Infrastructure(
                "streaming provider should not use complete".to_owned(),
            ))
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
        let delay = self
            .delays
            .lock()
            .expect("delays")
            .pop_front()
            .unwrap_or_default();
        let events = self
            .responses
            .lock()
            .expect("responses")
            .pop_front()
            .map_or_else(
                || {
                    vec![Err(maohuoban_ai_domain::ai::AiError::Infrastructure(
                        "missing scripted response".to_owned(),
                    ))]
                },
                response_to_stream_events,
            );

        async_stream::stream! {
            if !delay.is_zero() {
                tokio::time::sleep(delay).await;
            }
            for event in events {
                yield event;
            }
        }
        .boxed()
    }
}
