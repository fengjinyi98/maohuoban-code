use std::sync::Arc;

use futures_util::{StreamExt, stream::BoxStream};
use maohuoban_ai_domain::ai::{
    AiError, AiResult, LlmChatRequest, LlmStreamEvent, ProviderError, ProviderErrorCategory,
};

use crate::ai::ports::LlmProvider;

pub(super) fn model_stream(
    provider: Arc<dyn LlmProvider>,
    request: LlmChatRequest,
) -> BoxStream<'static, AiResult<LlmStreamEvent>> {
    Box::pin(async_stream::try_stream! {
        let mut stream = provider.stream(&request);
        while let Some(event) = stream.next().await {
            yield event?;
        }
    })
}

pub(super) fn empty_assistant_content_error() -> AiError {
    AiError::Provider(ProviderError::new(
        ProviderErrorCategory::InvalidResponse,
        "empty assistant content without tool calls",
    ))
}
