use std::sync::Arc;

use maohuoban_ai_application::ai::ports::LlmProvider;
#[cfg(test)]
use maohuoban_ai_infrastructure::provider::OpenAiCompatibleConfig;
use maohuoban_ai_infrastructure::provider::{
    LlmProviderRegistryConfig, build_llm_provider_from_registry_config,
};

/// `build_ai_llm_provider_from_provider_config` 构建 AI LLM Provider
/// 核心职责：
/// - 从运营配置注册表选择启用的默认 Provider
/// - 缺少可用配置时装配可降级的 Disabled Provider
#[must_use]
pub(crate) fn build_ai_llm_provider_from_provider_config(
    config: &LlmProviderRegistryConfig,
) -> Arc<dyn LlmProvider> {
    build_llm_provider_from_registry_config(config)
}

#[cfg(test)]
mod tests {
    use futures_util::StreamExt;
    use httpmock::MockServer;
    use maohuoban_ai_domain::ai::{
        LlmChatRequest, LlmDiagnosticsCorrelation, LlmMessage, LlmRole, LlmStreamEvent,
    };

    use super::{OpenAiCompatibleConfig, build_ai_llm_provider_from_provider_config};
    use maohuoban_ai_infrastructure::provider::{
        DeepSeekConfig, LlmProviderOperationalConfig, LlmProviderRegistryConfig,
    };

    fn sample_request() -> LlmChatRequest {
        LlmChatRequest {
            model: "primary".to_owned(),
            messages: vec![LlmMessage {
                role: LlmRole::User,
                content: "毛球今天怎么样".to_owned(),
                reasoning_content: None,
                tool_call_id: None,
                tool_calls: Vec::new(),
            }],
            tools: vec![],
            tool_choice: None,
            temperature: 0.2,
            stream: true,
            max_output_tokens: None,
            response_format: None,
            diagnostics_correlation: LlmDiagnosticsCorrelation::default(),
        }
    }

    #[tokio::test]
    async fn missing_provider_config_uses_disabled_provider() {
        let provider =
            build_ai_llm_provider_from_provider_config(&LlmProviderRegistryConfig::default());
        let events: Vec<_> = provider.stream(&sample_request()).collect().await;

        assert!(matches!(
            events.first(),
            Some(Err(error)) if error.stable_code() == "ai.provider.not_configured"
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

        let provider =
            build_ai_llm_provider_from_provider_config(&LlmProviderRegistryConfig::new(vec![
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
        let events: Vec<_> = provider.stream(&sample_request()).collect().await;

        mock.assert();
        assert!(events.iter().any(|event| {
            matches!(event, Ok(LlmStreamEvent::Delta { content }) if content == "真实")
        }));
        assert!(events.iter().any(|event| {
            matches!(
                event,
                Ok(LlmStreamEvent::Finish { usage, .. }) if usage.total_tokens == 5
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

        let provider =
            build_ai_llm_provider_from_provider_config(&LlmProviderRegistryConfig::new(vec![
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
        let events: Vec<_> = provider.stream(&sample_request()).collect().await;

        mock.assert();
        assert!(events.iter().any(|event| {
            matches!(event, Ok(LlmStreamEvent::Delta { content }) if content == "DeepSeek")
        }));
        assert!(events.iter().any(|event| {
            matches!(event, Ok(LlmStreamEvent::Finish { usage, .. }) if usage.total_tokens == 5)
        }));
    }
}
