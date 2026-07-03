use std::sync::{Arc, Mutex};

use futures_util::StreamExt;
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_domain::ai::{
    AiError, AiResult, LlmChatRequest, LlmChatResponse, LlmFinishReason, LlmStreamEvent, LlmUsage,
};

/// `RecordingStreamProvider` 记录流式请求的测试 provider
/// 核心职责：
/// - 记录 runtime 发送给模型的请求
/// - 返回固定流式 delta，避免测试依赖真实模型
#[derive(Clone, Default)]
pub struct RecordingStreamProvider {
    requests: Arc<Mutex<Vec<LlmChatRequest>>>,
}

impl RecordingStreamProvider {
    pub fn take_requests(&self) -> Vec<LlmChatRequest> {
        self.requests.lock().expect("requests").clone()
    }
}

impl LlmProvider for RecordingStreamProvider {
    fn complete<'a>(
        &'a self,
        _request: &'a LlmChatRequest,
    ) -> std::pin::Pin<Box<dyn std::future::Future<Output = AiResult<LlmChatResponse>> + Send + 'a>>
    {
        Box::pin(async {
            Err(AiError::Infrastructure(
                "complete should not be used".to_owned(),
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
            Ok(LlmStreamEvent::Delta {
                content: "公共回答".to_owned(),
            }),
            Ok(LlmStreamEvent::Finish {
                finish_reason: LlmFinishReason::Stop,
                usage: LlmUsage::default(),
            }),
        ])
        .boxed()
    }
}
