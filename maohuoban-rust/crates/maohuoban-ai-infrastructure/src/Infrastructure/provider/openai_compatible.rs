//! openai_compatible OpenAI 兼容 Provider 实现
//! 核心职责：
//! - 将内部 LlmChatRequest 转换为 OpenAI 兼容 HTTP 请求
//! - 解析非流式响应为内部 LlmChatResponse
//! - 密钥只在 Bearer header 中使用，不进入日志

use std::future::Future;
use std::pin::Pin;
use std::time::Duration;

use futures_util::stream::{BoxStream, StreamExt};
use maohuoban_ai_application::ai::model_router::{ModelRouteConfig, ModelRouter};
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_domain::ai::{
    AiError, AiResult, LlmChatRequest, LlmChatResponse, LlmFinishReason, LlmMessage, LlmRole,
    LlmStreamEvent, LlmToolCall, LlmUsage, ProviderError, ProviderErrorCategory,
};
use reqwest::header::{AUTHORIZATION, CONTENT_TYPE, HeaderMap};

use super::OpenAiCompatibleConfig;

/// OpenAiCompatibleLlmProvider OpenAI 兼容 Provider
/// 核心职责：
/// - 将内部请求适配为 OpenAI 兼容 HTTP 调用
/// - 处理 base_url 归一化、Bearer 认证和错误映射
pub struct OpenAiCompatibleLlmProvider {
    config: OpenAiCompatibleConfig,
    client: reqwest::Client,
    model_router: ModelRouter,
}

impl OpenAiCompatibleLlmProvider {
    /// new 构造 Provider
    #[must_use]
    pub fn new(config: OpenAiCompatibleConfig) -> Self {
        let client = reqwest::Client::builder()
            .timeout(Duration::from_secs(config.timeout_secs))
            .build()
            .unwrap_or_else(|_| reqwest::Client::new());
        let model_router = Self::build_model_router(&config.model);
        Self {
            config,
            client,
            model_router,
        }
    }

    /// build_model_router 构造首期内存模型路由
    /// 核心职责：
    /// - 将冻结模型 label 映射到当前 provider 配置模型
    /// - 保留直接传入配置模型名的兼容路径
    fn build_model_router(model: &str) -> ModelRouter {
        ModelRouter::new([
            ModelRouteConfig::new("lite", model),
            ModelRouteConfig::new("primary", model),
            ModelRouteConfig::new("pro", model),
            ModelRouteConfig::new("memory", model),
            ModelRouteConfig::new(model, model),
        ])
    }

    /// completions_url 归一化 base_url 为完整 endpoint
    fn completions_url(&self) -> String {
        if self.config.base_url.ends_with("/v1") {
            format!("{}/chat/completions", self.config.base_url)
        } else if self.config.base_url.ends_with('/') {
            format!("{}v1/chat/completions", self.config.base_url)
        } else {
            format!("{}/v1/chat/completions", self.config.base_url)
        }
    }

    /// build_headers 构造认证 headers
    fn build_headers(&self) -> HeaderMap {
        let mut headers = HeaderMap::new();
        headers.insert(CONTENT_TYPE, "application/json".parse().unwrap());
        headers.insert(
            AUTHORIZATION,
            format!("Bearer {}", self.config.api_key).parse().unwrap(),
        );
        headers
    }

    /// build_body 构造 OpenAI 兼容请求体
    fn build_body(&self, request: &LlmChatRequest, model: &str) -> serde_json::Value {
        let messages: Vec<serde_json::Value> = request
            .messages
            .iter()
            .map(|m| {
                let mut msg = serde_json::json!({
                    "role": match m.role {
                        LlmRole::System => "system",
                        LlmRole::User => "user",
                        LlmRole::Assistant => "assistant",
                        LlmRole::Tool => "tool",
                    },
                    "content": m.content,
                });
                if let Some(id) = &m.tool_call_id {
                    msg["tool_call_id"] = serde_json::Value::String(id.clone());
                }
                msg
            })
            .collect();

        let tools: Vec<serde_json::Value> = request
            .tools
            .iter()
            .map(|t| {
                serde_json::json!({
                    "type": "function",
                    "function": {
                        "name": t.name,
                        "description": t.description,
                        "parameters": t.parameters,
                    }
                })
            })
            .collect();

        let mut body = serde_json::json!({
            "model": model,
            "messages": messages,
            "temperature": self.config.temperature,
            "stream": request.stream,
        });

        if !tools.is_empty() {
            body["tools"] = serde_json::Value::Array(tools);
        }
        if let Some(choice) = &request.tool_choice {
            body["tool_choice"] = serde_json::Value::String(choice.clone());
        }
        if let Some(max) = request.max_output_tokens.or(self.config.max_output_tokens) {
            body["max_tokens"] = serde_json::Value::Number(max.into());
        }
        if let Some(fmt) = request
            .response_format
            .clone()
            .or_else(|| self.config.response_format.clone())
        {
            body["response_format"] = fmt;
        }

        body
    }

    /// map_status_error 将 HTTP 状态码映射为稳定错误
    fn map_status_error(status: u16, body: &str) -> AiError {
        let category = match status {
            401 | 403 => ProviderErrorCategory::NotConfigured,
            429 => ProviderErrorCategory::RateLimited,
            s if s >= 500 => ProviderErrorCategory::Upstream,
            _ => ProviderErrorCategory::Upstream,
        };
        AiError::Provider(ProviderError::new(
            category,
            format!("http {status}: {body}"),
        ))
    }

    /// map_request_error 将 reqwest 错误映射为 Provider 分类
    fn map_request_error(error: &reqwest::Error) -> AiError {
        let category = if error.is_timeout() {
            ProviderErrorCategory::Timeout
        } else {
            ProviderErrorCategory::Upstream
        };
        AiError::Provider(ProviderError::new(category, error.to_string()))
    }

    /// provider_error 构造 Provider 分类错误
    fn provider_error(category: ProviderErrorCategory, message: impl Into<String>) -> AiError {
        AiError::Provider(ProviderError::new(category, message))
    }

    /// resolve_request_model 解析请求模型 label
    /// 核心职责：
    /// - 将业务请求中的模型 label 转换为 provider model
    /// - 未配置或未知 label 不发起上游 HTTP 调用
    fn resolve_request_model(&self, request: &LlmChatRequest) -> AiResult<String> {
        self.model_router
            .resolve(&request.model)
            .map(|route| route.model().to_owned())
            .map_err(|error| {
                Self::provider_error(
                    ProviderErrorCategory::NotConfigured,
                    format!("model route unavailable: {error}"),
                )
            })
    }

    /// parse_response 解析 OpenAI 兼容非流式响应
    fn parse_response(body: &str) -> AiResult<LlmChatResponse> {
        let json: serde_json::Value = serde_json::from_str(body).map_err(|error| {
            Self::provider_error(
                ProviderErrorCategory::InvalidResponse,
                format!("invalid json: {error}"),
            )
        })?;

        let choice = json.get("choices").and_then(|c| c.get(0)).ok_or_else(|| {
            Self::provider_error(
                ProviderErrorCategory::InvalidResponse,
                "no choices in response",
            )
        })?;

        let message = choice.get("message").ok_or_else(|| {
            Self::provider_error(
                ProviderErrorCategory::InvalidResponse,
                "no message in choice",
            )
        })?;

        let content = message
            .get("content")
            .and_then(|c| c.as_str())
            .unwrap_or("")
            .to_owned();

        let finish_reason_str = choice
            .get("finish_reason")
            .and_then(|f| f.as_str())
            .unwrap_or("stop");
        let finish_reason = match finish_reason_str {
            "length" => LlmFinishReason::Length,
            "tool_calls" => LlmFinishReason::ToolCalls,
            "content_filter" => LlmFinishReason::ContentFilter,
            _ => LlmFinishReason::Stop,
        };

        let tool_calls: Vec<LlmToolCall> = message
            .get("tool_calls")
            .and_then(|tc| tc.as_array())
            .map(|arr| {
                arr.iter()
                    .filter_map(|tc| {
                        let id = tc.get("id")?.as_str()?.to_owned();
                        let function = tc.get("function")?;
                        let name = function.get("name")?.as_str()?.to_owned();
                        let arguments = function
                            .get("arguments")
                            .and_then(|a| a.as_str())
                            .unwrap_or("{}")
                            .to_owned();
                        Some(LlmToolCall {
                            id,
                            name,
                            arguments,
                        })
                    })
                    .collect()
            })
            .unwrap_or_default();

        if tool_calls.is_empty() && content.trim().is_empty() {
            return Err(Self::provider_error(
                ProviderErrorCategory::InvalidResponse,
                "empty assistant content without tool calls",
            ));
        }

        let usage = json
            .get("usage")
            .map(|u| LlmUsage {
                input_tokens: u
                    .get("prompt_tokens")
                    .and_then(serde_json::Value::as_u64)
                    .unwrap_or(0) as u32,
                output_tokens: u
                    .get("completion_tokens")
                    .and_then(serde_json::Value::as_u64)
                    .unwrap_or(0) as u32,
                total_tokens: u
                    .get("total_tokens")
                    .and_then(serde_json::Value::as_u64)
                    .unwrap_or(0) as u32,
            })
            .unwrap_or_default();

        let model = json
            .get("model")
            .and_then(|m| m.as_str())
            .unwrap_or("")
            .to_owned();

        Ok(LlmChatResponse {
            message: LlmMessage {
                role: LlmRole::Assistant,
                content,
                tool_call_id: None,
                tool_calls: tool_calls.clone(),
            },
            tool_calls,
            usage,
            finish_reason,
            provider: "openai_compatible".to_owned(),
            model,
        })
    }
}

impl LlmProvider for OpenAiCompatibleLlmProvider {
    fn complete<'a>(
        &'a self,
        request: &'a LlmChatRequest,
    ) -> Pin<Box<dyn Future<Output = AiResult<LlmChatResponse>> + Send + 'a>> {
        Box::pin(async move {
            let url = self.completions_url();
            let headers = self.build_headers();
            let model = self.resolve_request_model(request)?;
            let body = self.build_body(request, &model);

            let response = self
                .client
                .post(&url)
                .headers(headers)
                .json(&body)
                .send()
                .await
                .map_err(|error| Self::map_request_error(&error))?;

            let status = response.status().as_u16();
            let text = response
                .text()
                .await
                .map_err(|error| Self::map_request_error(&error))?;

            if status >= 400 {
                return Err(Self::map_status_error(status, &text));
            }

            Self::parse_response(&text)
        })
    }

    fn stream<'a>(
        &'a self,
        request: &'a LlmChatRequest,
    ) -> BoxStream<'a, AiResult<LlmStreamEvent>> {
        let url = self.completions_url();
        let headers = self.build_headers();
        let model = match self.resolve_request_model(request) {
            Ok(model) => model,
            Err(error) => return futures_util::stream::once(async { Err(error) }).boxed(),
        };
        let mut body = self.build_body(request, &model);
        body["stream"] = serde_json::Value::Bool(true);

        let client = self.client.clone();

        async_stream::stream! {
            let response = match client
                .post(&url)
                .headers(headers)
                .json(&body)
                .send()
                .await
            {
                Ok(r) => r,
                Err(e) => {
                    yield Err(Self::map_request_error(&e));
                    return;
                }
            };

            let status = response.status().as_u16();
            if status >= 400 {
                let text = response.text().await.unwrap_or_default();
                yield Err(Self::map_status_error(status, &text));
                return;
            }

            use futures_util::StreamExt as _;
            let mut stream = response.bytes_stream();
            let mut buffer = String::new();
            let mut stream_completed = false;

            while let Some(chunk_result) = stream.next().await {
                match chunk_result {
                    Ok(bytes) => {
                        let chunk = String::from_utf8_lossy(&bytes);
                        if chunk.contains("[DONE]") {
                            stream_completed = true;
                        }
                        buffer.push_str(&chunk);
                        let (events, remaining) = crate::provider::sse::parse_sse_buffer(&buffer);
                        buffer = remaining;
                        for event in events {
                            match event {
                                Ok(e) => {
                                    if matches!(e, LlmStreamEvent::Finish { .. }) {
                                        stream_completed = true;
                                    }
                                    yield Ok(e);
                                }
                                Err(e) => {
                                    yield Err(e);
                                    return;
                                }
                            }
                        }
                    }
                    Err(e) => {
                        yield Err(Self::provider_error(
                            ProviderErrorCategory::StreamInterrupted,
                            e.to_string(),
                        ));
                        return;
                    }
                }
            }

            if !buffer.trim().is_empty() || !stream_completed {
                yield Err(Self::provider_error(
                    ProviderErrorCategory::StreamInterrupted,
                    "stream ended before completion marker",
                ));
            }
        }
        .boxed()
    }
}
