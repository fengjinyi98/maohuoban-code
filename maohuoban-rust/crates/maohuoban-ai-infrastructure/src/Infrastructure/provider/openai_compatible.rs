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
    AiError, AiResult, LlmChatRequest, LlmChatResponse, LlmStreamEvent, ProviderError,
    ProviderErrorCategory,
};
use reqwest::header::{AUTHORIZATION, CONTENT_TYPE, HeaderMap};

use super::OpenAiCompatibleConfig;
use super::openai_body::build_openai_body;
use super::openai_diagnostics::OpenAiProviderDiagnostics;
use super::openai_response::parse_openai_response;
use super::openai_stream_event::{header_summary, stream_event_name, stream_event_payload};
use super::openai_stream_stats::ProviderStreamStats;

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

    /// record_request_prepared 记录 Provider 请求摘要
    /// 核心职责：
    /// - 复用 diagnostics 记录实际发出的 OpenAI 兼容请求体
    /// - 避免 stream / complete 路径散写同类诊断字段
    fn record_request_prepared(
        &self,
        mode: &'static str,
        request: &LlmChatRequest,
        body: &serde_json::Value,
        model: &str,
    ) {
        OpenAiProviderDiagnostics::record_request_prepared(
            mode,
            request,
            body,
            model,
            &self.config.base_url,
        );
    }

    /// record_http_response_started 记录 Provider HTTP 响应摘要
    /// 核心职责：
    /// - 记录状态码和内容类型族
    /// - 不读取或记录响应 body
    fn record_http_response_started(
        mode: &'static str,
        request: &LlmChatRequest,
        model: &str,
        status: u16,
        headers: &HeaderMap,
    ) {
        let content_type = headers
            .get(CONTENT_TYPE)
            .and_then(|value| value.to_str().ok());
        let header_summary = header_summary(headers);
        OpenAiProviderDiagnostics::record_http_response_started(
            mode,
            request,
            model,
            status,
            content_type,
            &header_summary,
        );
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
            let body = build_openai_body(request, &model);
            self.record_request_prepared("complete", request, &body, &model);

            let response = self
                .client
                .post(&url)
                .headers(headers)
                .json(&body)
                .send()
                .await
                .map_err(|error| Self::map_request_error(&error))?;

            let status = response.status().as_u16();
            Self::record_http_response_started(
                "complete",
                request,
                &model,
                status,
                response.headers(),
            );
            let text = response
                .text()
                .await
                .map_err(|error| Self::map_request_error(&error))?;
            OpenAiProviderDiagnostics::record_http_response_body(
                "complete", request, &model, status, &text,
            );

            if status >= 400 {
                return Err(Self::map_status_error(status, &text));
            }

            parse_openai_response(&text)
        })
    }

    #[allow(clippy::too_many_lines)]
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
        let mut body = build_openai_body(request, &model);
        body["stream"] = serde_json::Value::Bool(true);
        self.record_request_prepared("stream", request, &body, &model);

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
            Self::record_http_response_started(
                "stream",
                request,
                &model,
                status,
                response.headers(),
            );
            if status >= 400 {
                let text = response.text().await.unwrap_or_default();
                OpenAiProviderDiagnostics::record_http_response_body(
                    "stream", request, &model, status, &text,
                );
                yield Err(Self::map_status_error(status, &text));
                return;
            }

            use futures_util::StreamExt as _;
            let mut stream = response.bytes_stream();
            let mut decoder = crate::provider::sse::SseStreamDecoder::new();
            let mut stream_stats = ProviderStreamStats::default();

            while let Some(chunk_result) = stream.next().await {
                match chunk_result {
                    Ok(bytes) => {
                        stream_stats.chunk_count = stream_stats.chunk_count.saturating_add(1);
                        let chunk = String::from_utf8_lossy(&bytes);
                        OpenAiProviderDiagnostics::record_stream_chunk(
                            request,
                            &model,
                            stream_stats.chunk_count,
                            bytes.len(),
                            &chunk,
                        );
                        if chunk.contains("[DONE]") {
                            stream_stats.stream_completed = true;
                        }
                        for event in decoder.push_str(&chunk) {
                            match event {
                                Ok(e) => {
                                    stream_stats.observe_event(&e);
                                    OpenAiProviderDiagnostics::record_stream_event(
                                        request,
                                        &model,
                                        stream_event_name(&e),
                                        stream_event_payload(&e),
                                    );
                                    yield Ok(e);
                                }
                                Err(e) => {
                                    OpenAiProviderDiagnostics::record_stream_decode_error(
                                        request,
                                        &model,
                                        &e,
                                        stream_stats,
                                        decoder.is_idle(),
                                    );
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

            let decoder_idle = decoder.is_idle();
            if !decoder_idle || !stream_stats.stream_completed {
                OpenAiProviderDiagnostics::record_stream_incomplete(
                    request,
                    &model,
                    stream_stats,
                    decoder_idle,
                );
                yield Err(Self::provider_error(
                    ProviderErrorCategory::StreamInterrupted,
                    "stream ended before completion marker",
                ));
            } else {
                OpenAiProviderDiagnostics::record_stream_completed(
                    request,
                    &model,
                    stream_stats,
                    decoder_idle,
                );
            }
        }
        .boxed()
    }
}
