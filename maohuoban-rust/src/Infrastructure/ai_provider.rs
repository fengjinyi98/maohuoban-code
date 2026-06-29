use std::sync::Arc;

use maohuoban_ai_application::ai::ports::LlmProvider;
#[cfg(test)]
use maohuoban_ai_application::ai::stream::AiStreamPipeline;
#[cfg(test)]
use maohuoban_ai_infrastructure::provider::OpenAiCompatibleConfig;
use maohuoban_ai_infrastructure::provider::{
    LlmProviderRegistryConfig, build_llm_provider_from_registry_config,
};

/// build_ai_llm_provider_from_provider_config 构建 AI LLM Provider
/// 核心职责：
/// - 从运营配置注册表选择启用的默认 Provider
/// - 缺少可用配置时装配可降级的 Disabled Provider
#[must_use]
pub(crate) fn build_ai_llm_provider_from_provider_config(
    config: &LlmProviderRegistryConfig,
) -> Arc<dyn LlmProvider> {
    build_llm_provider_from_registry_config(config)
}

/// build_ai_stream_pipeline_from_provider_config 构建 AI 流式 pipeline
/// 核心职责：
/// - 从运营配置注册表选择启用的默认 Provider
/// - 缺少可用配置时装配可降级的 Disabled Provider
#[must_use]
#[cfg(test)]
pub(crate) fn build_ai_stream_pipeline_from_provider_config(
    config: &LlmProviderRegistryConfig,
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
    use maohuoban_ai_infrastructure::provider::{
        DeepSeekConfig, LlmProviderOperationalConfig, LlmProviderRegistryConfig,
    };

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
        let pipeline =
            build_ai_stream_pipeline_from_provider_config(&LlmProviderRegistryConfig::default());
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
            build_ai_stream_pipeline_from_provider_config(&LlmProviderRegistryConfig::new(vec![
                LlmProviderOperationalConfig::from_openai_compatible_config(
                    "test-openai-compatible",
                    "Test OpenAI Compatible",
                    true,
                    true,
                    OpenAiCompatibleConfig {
                        base_url: server.base_url(),
                        api_key: "test-api-key".to_owned(),
                        model: "test-model".to_owned(),
                        timeout_secs: 5,
                        temperature: 0.2,
                        max_output_tokens: None,
                        response_format: None,
                    },
                ),
            ]));
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

    #[tokio::test]
    async fn available_deepseek_provider_config_uses_provider_factory() {
        let server = MockServer::start();
        let mock = server.mock(|when, then| {
            when.method(httpmock::Method::POST)
                .path("/v1/chat/completions")
                .header("authorization", "Bearer deepseek-test-key")
                .body_contains("\"model\":\"deepseek-v4-flash\"");
            then.status(200)
                .header("content-type", "text/event-stream")
                .body(
                    "data: {\"choices\":[{\"delta\":{\"content\":\"DeepSeek\"}}]}\n\n\
                     data: {\"choices\":[{\"delta\":{\"content\":\" OK\"}}]}\n\n\
                     data: {\"choices\":[{\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":2,\"completion_tokens\":3,\"total_tokens\":5}}\n\n\
                     data: [DONE]\n\n",
                );
        });

        let pipeline =
            build_ai_stream_pipeline_from_provider_config(&LlmProviderRegistryConfig::new(vec![
                LlmProviderOperationalConfig::from_deepseek_config(
                    "deepseek",
                    "DeepSeek",
                    true,
                    true,
                    DeepSeekConfig {
                        base_url: server.base_url(),
                        api_key: "deepseek-test-key".to_owned(),
                        model: "deepseek-v4-flash".to_owned(),
                        timeout_secs: 5,
                        temperature: 0.2,
                        max_output_tokens: None,
                        response_format: None,
                    },
                ),
            ]));
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
            matches!(
                event,
                Ok(AiStreamEvent::MessageCompleted { final_text, usage, .. })
                    if final_text == "DeepSeek OK" && usage.total_tokens == 5
            )
        }));
    }
}
