use std::future::Future;
use std::pin::Pin;
use std::sync::{Arc, Mutex};

use futures_util::stream::BoxStream;
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_domain::ai::{AiResult, LlmChatResponse, LlmStreamEvent};

use crate::support::fixtures::fake_llm_response;

/// `CapturingLlmProvider` 捕获 LLM 请求内容的 fake provider
/// 核心职责：
/// - 记录收到的 LLM 请求文本
/// - 验证内部字段是否在摘要投影中被过滤
pub struct CapturingLlmProvider {
    response: LlmChatResponse,
    captured: Arc<Mutex<Option<String>>>,
}

impl CapturingLlmProvider {
    pub fn new(summary_text: &str, captured: Arc<Mutex<Option<String>>>) -> Self {
        Self {
            response: fake_llm_response(summary_text),
            captured,
        }
    }
}

impl LlmProvider for CapturingLlmProvider {
    fn complete<'a>(
        &'a self,
        request: &'a maohuoban_ai_domain::ai::LlmChatRequest,
    ) -> Pin<Box<dyn Future<Output = AiResult<LlmChatResponse>> + Send + 'a>> {
        let captured = self.captured.clone();
        let response = self.response.clone();
        Box::pin(async move {
            let text = request
                .messages
                .iter()
                .map(|m| m.content.as_str())
                .collect::<Vec<_>>()
                .join("\n");
            *captured.lock().expect("lock") = Some(text);
            Ok(response)
        })
    }

    fn stream<'a>(
        &'a self,
        _request: &'a maohuoban_ai_domain::ai::LlmChatRequest,
    ) -> BoxStream<'a, AiResult<LlmStreamEvent>> {
        Box::pin(futures_util::stream::empty())
    }
}
