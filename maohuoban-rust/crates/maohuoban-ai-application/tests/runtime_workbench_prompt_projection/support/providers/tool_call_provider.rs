use std::sync::{Arc, Mutex};

use futures_util::StreamExt;
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_domain::ai::{
    AiResult, LlmChatRequest, LlmChatResponse, LlmFinishReason, LlmStreamEvent, LlmToolCall,
    LlmUsage,
};

#[derive(Clone)]
pub struct ToolCallProvider {
    requests: Arc<Mutex<Vec<LlmChatRequest>>>,
}

impl ToolCallProvider {
    pub fn new() -> Self {
        Self {
            requests: Arc::new(Mutex::new(Vec::new())),
        }
    }

    pub fn take_requests(&self) -> Vec<LlmChatRequest> {
        self.requests.lock().expect("requests").clone()
    }
}

impl LlmProvider for ToolCallProvider {
    fn complete<'a>(
        &'a self,
        _request: &LlmChatRequest,
    ) -> std::pin::Pin<Box<dyn std::future::Future<Output = AiResult<LlmChatResponse>> + Send + 'a>>
    {
        Box::pin(async {
            Err(maohuoban_ai_domain::ai::AiError::Infrastructure(
                "runtime should use stream".to_owned(),
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
        futures_util::stream::iter(vec![
            Ok(LlmStreamEvent::ToolCall {
                tool_call: LlmToolCall {
                    id: "call_prepare_write".to_owned(),
                    name: "prepare_pet_observation_write".to_owned(),
                    arguments: "{}".to_owned(),
                },
            }),
            Ok(LlmStreamEvent::Finish {
                finish_reason: LlmFinishReason::ToolCalls,
                usage: LlmUsage::default(),
            }),
        ])
        .boxed()
    }
}
