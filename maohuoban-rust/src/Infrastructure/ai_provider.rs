use std::sync::Arc;

use maohuoban_ai_application::ai::ports::{DisabledLlmProvider, LlmProvider};
#[cfg(test)]
use maohuoban_ai_application::ai::stream::AiStreamPipeline;
use maohuoban_ai_infrastructure::provider::{OpenAiCompatibleConfig, OpenAiCompatibleLlmProvider};

/// build_ai_llm_provider_from_provider_config 构建 AI LLM Provider
/// 核心职责：
/// - 有 OpenAI 兼容配置时装配真实 Provider
/// - 缺少配置时装配可降级的 Disabled Provider
#[must_use]
pub(crate) fn build_ai_llm_provider_from_provider_config(
    config: Option<OpenAiCompatibleConfig>,
) -> Arc<dyn LlmProvider> {
    match config {
        Some(config) => Arc::new(OpenAiCompatibleLlmProvider::new(config)),
        None => Arc::new(DisabledLlmProvider),
    }
}

/// build_ai_stream_pipeline_from_provider_config 构建 AI 流式 pipeline
/// 核心职责：
/// - 有 OpenAI 兼容配置时装配真实 Provider
/// - 缺少配置时装配可降级的 Disabled Provider
#[must_use]
#[cfg(test)]
pub(crate) fn build_ai_stream_pipeline_from_provider_config(
    config: Option<OpenAiCompatibleConfig>,
) -> AiStreamPipeline {
    let provider = build_ai_llm_provider_from_provider_config(config);
    AiStreamPipeline::from_provider(provider)
}

#[cfg(test)]
mod tests {
    use futures_util::StreamExt;
    use httpmock::MockServer;
    use maohuoban_ai_domain::ai::{AiStreamEvent, LlmChatRequest, LlmMessage, LlmRole};
    use uuid::Uuid;

    use super::{OpenAiCompatibleConfig, build_ai_stream_pipeline_from_provider_config};

    fn sample_request() -> LlmChatRequest {
        LlmChatRequest {
            model: "primary".to_owned(),
            messages: vec![LlmMessage {
                role: LlmRole::User,
                content: "毛球今天怎么样".to_owned(),
                tool_call_id: None,
                tool_calls: Vec::new(),
            }],
            tools: vec![],
            tool_choice: None,
            temperature: 0.2,
            stream: true,
            max_output_tokens: None,
            response_format: None,
        }
    }

    #[tokio::test]
    async fn missing_provider_config_uses_disabled_provider() {
        let pipeline = build_ai_stream_pipeline_from_provider_config(None);
        let events: Vec<_> = pipeline
            .run(
                sample_request(),
                Uuid::new_v4(),
                Uuid::new_v4(),
                "测试".to_owned(),
            )
            .collect()
            .await;

        assert!(matches!(
            events.first(),
            Some(Ok(AiStreamEvent::MessageStarted { .. }))
        ));
        assert!(matches!(
            events.get(1),
            Some(Ok(AiStreamEvent::Error { code, .. })) if code == "ai.provider.not_configured"
        ));
    }

    #[tokio::test]
    async fn available_provider_config_uses_openai_compatible_provider() {
        let server = MockServer::start();
        let mock = server.mock(|when, then| {
            when.method(httpmock::Method::POST)
                .path("/v1/chat/completions")
                .header("authorization", "Bearer test-api-key");
            then.status(200)
                .header("content-type", "text/event-stream")
                .body(
                    "data: {\"choices\":[{\"delta\":{\"content\":\"真实\"}}]}\n\n\
                     data: {\"choices\":[{\"delta\":{\"content\":\" Provider\"}}]}\n\n\
                     data: {\"choices\":[{\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":2,\"completion_tokens\":3,\"total_tokens\":5}}\n\n\
                     data: [DONE]\n\n",
                );
        });

        let pipeline =
            build_ai_stream_pipeline_from_provider_config(Some(OpenAiCompatibleConfig {
                base_url: server.base_url(),
                api_key: "test-api-key".to_owned(),
                model: "test-model".to_owned(),
                timeout_secs: 5,
                temperature: 0.2,
                max_output_tokens: None,
            }));
        let events: Vec<_> = pipeline
            .run(
                sample_request(),
                Uuid::new_v4(),
                Uuid::new_v4(),
                "测试".to_owned(),
            )
            .collect()
            .await;

        mock.assert();
        assert!(events.iter().any(|event| {
            matches!(event, Ok(AiStreamEvent::Delta { text }) if text == "真实")
        }));
        assert!(events.iter().any(|event| {
            matches!(
                event,
                Ok(AiStreamEvent::MessageCompleted { final_text, usage, .. })
                    if final_text == "真实 Provider" && usage.total_tokens == 5
            )
        }));
    }
}
