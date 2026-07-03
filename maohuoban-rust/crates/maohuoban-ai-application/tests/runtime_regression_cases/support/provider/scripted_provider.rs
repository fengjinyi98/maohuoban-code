use std::collections::VecDeque;
use std::sync::{Arc, Mutex};

use futures_util::StreamExt;
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_domain::ai::{LlmChatRequest, LlmChatResponse, LlmStreamEvent};

use super::responses::response_to_stream_events;

/// `ScriptedProvider` Runtime 回归测试脚本化模型提供者
/// 核心职责：
/// - 按顺序返回预置模型响应
/// - 记录 Runtime 发送给模型的请求用于断言
#[derive(Clone)]
pub struct ScriptedProvider {
    requests: Arc<Mutex<Vec<LlmChatRequest>>>,
    responses: Arc<Mutex<VecDeque<LlmChatResponse>>>,
}

impl ScriptedProvider {
    pub fn new(responses: Vec<LlmChatResponse>) -> Self {
        Self {
            requests: Arc::new(Mutex::new(Vec::new())),
            responses: Arc::new(Mutex::new(VecDeque::from(responses))),
        }
    }

    pub fn take_requests(&self) -> Vec<LlmChatRequest> {
        self.requests.lock().expect("requests").clone()
    }
}

impl LlmProvider for ScriptedProvider {
    fn complete<'a>(
        &'a self,
        request: &'a LlmChatRequest,
    ) -> std::pin::Pin<
        Box<
            dyn std::future::Future<Output = maohuoban_ai_domain::ai::AiResult<LlmChatResponse>>
                + Send
                + 'a,
        >,
    > {
        let response = self.responses.clone();
        let requests = self.requests.clone();
        let request = request.clone();
        Box::pin(async move {
            requests.lock().expect("requests").push(request);
            response
                .lock()
                .expect("responses")
                .pop_front()
                .ok_or_else(|| {
                    maohuoban_ai_domain::ai::AiError::Infrastructure(
                        "missing scripted response".to_owned(),
                    )
                })
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
        futures_util::stream::iter(events).boxed()
    }
}
