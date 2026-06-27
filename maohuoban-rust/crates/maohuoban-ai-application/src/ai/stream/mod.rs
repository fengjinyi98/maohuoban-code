//! stream 后端稳定 SSE 事件 pipeline
//! 核心职责：
//! - 将 Provider 的 LlmStreamEvent 序列转换为毛伙伴稳定 AiStreamEvent 序列
//! - 事件顺序固定: message_started -> delta* -> message_completed
//! - Provider 错误转为 error 事件

use std::sync::Arc;

use futures_util::stream::{BoxStream, StreamExt};
use maohuoban_ai_domain::ai::{
    AiError, AiFactPackage, AiPetDisplaySnapshot, AiStreamEvent, LlmChatRequest, LlmFinishReason,
    LlmStreamEvent,
};

use crate::ai::ports::LlmProvider;
use crate::ai::verifier::AiAnswerVerifier;

/// AiStreamPipeline 流式事件 pipeline
/// 核心职责：
/// - 包装 LlmProvider，输出稳定 SSE 事件
/// - 累积 delta 文本，完成时输出 message_completed
pub struct AiStreamPipeline {
    provider: Arc<dyn LlmProvider>,
}

/// AiStreamRunContext 流式运行上下文
/// 核心职责：
/// - 汇总稳定 SSE 所需的会话、消息、宠物和初始事件参数
/// - 携带真实事实包供回答校验器使用
pub struct AiStreamRunContext {
    pub chat_session_id: uuid::Uuid,
    pub message_id: uuid::Uuid,
    pub title: String,
    pub target_pet: Option<AiPetDisplaySnapshot>,
    pub initial_events: Vec<AiStreamEvent>,
    pub fact_package: Option<AiFactPackage>,
}

impl AiStreamPipeline {
    /// new 构造 pipeline
    #[must_use]
    pub fn new(provider: impl LlmProvider + 'static) -> Self {
        Self {
            provider: Arc::new(provider),
        }
    }

    /// run 启动流式 pipeline
    /// 核心职责：
    /// - 首先发送 message_started 事件
    /// - 逐个消费 Provider stream event，发送 delta 事件
    /// - 收到 finish 时发送 message_completed
    /// - 遇到错误发送 error 事件
    #[must_use]
    pub fn run(
        &self,
        request: LlmChatRequest,
        chat_session_id: uuid::Uuid,
        message_id: uuid::Uuid,
        title: String,
    ) -> BoxStream<'static, Result<AiStreamEvent, AiError>> {
        self.run_with_target_pet(request, chat_session_id, message_id, title, None)
    }

    /// run_with_target_pet 启动带目标宠物快照的流式 pipeline
    /// 核心职责：
    /// - 在 message_started 中携带后端解析出的宠物展示快照
    /// - 继续保持 Provider delta 到稳定 SSE 事件的转换
    #[must_use]
    pub fn run_with_target_pet(
        &self,
        request: LlmChatRequest,
        chat_session_id: uuid::Uuid,
        message_id: uuid::Uuid,
        title: String,
        target_pet: Option<AiPetDisplaySnapshot>,
    ) -> BoxStream<'static, Result<AiStreamEvent, AiError>> {
        self.run_with_target_pet_and_initial_events(
            request,
            chat_session_id,
            message_id,
            title,
            target_pet,
            vec![],
        )
    }

    /// run_with_target_pet_and_initial_events 启动带初始事件的流式 pipeline
    /// 核心职责：
    /// - 在 message_started 后输出工具调用、解析等应用层初始事件
    /// - 再消费 Provider stream 并输出 delta / completed
    #[must_use]
    pub fn run_with_target_pet_and_initial_events(
        &self,
        request: LlmChatRequest,
        chat_session_id: uuid::Uuid,
        message_id: uuid::Uuid,
        title: String,
        target_pet: Option<AiPetDisplaySnapshot>,
        initial_events: Vec<AiStreamEvent>,
    ) -> BoxStream<'static, Result<AiStreamEvent, AiError>> {
        self.run_with_context(
            request,
            AiStreamRunContext {
                chat_session_id,
                message_id,
                title,
                target_pet,
                initial_events,
                fact_package: None,
            },
        )
    }

    /// run_with_context 启动带运行上下文的流式 pipeline
    /// 核心职责：
    /// - 在 message_started 后输出应用层初始事件
    /// - 使用真实事实包校验 Provider 最终回答
    #[must_use]
    pub fn run_with_context(
        &self,
        request: LlmChatRequest,
        context: AiStreamRunContext,
    ) -> BoxStream<'static, Result<AiStreamEvent, AiError>> {
        let provider = self.provider.clone();

        async_stream::stream! {
            // 1. 发送 message_started
            yield Ok(AiStreamEvent::MessageStarted {
                chat_session_id: context.chat_session_id,
                message_id: context.message_id,
                target_pet: context.target_pet,
                title: context.title,
            });

            for event in context.initial_events {
                yield Ok(event);
            }

            // 2. 消费 Provider stream，并先缓冲 delta，避免违规内容在校验前透出。
            let mut stream = provider.stream(&request);
            let mut delta_chunks = Vec::new();
            let mut finish_reason = LlmFinishReason::Stop;
            let mut usage = maohuoban_ai_domain::ai::LlmUsage::default();

            while let Some(event_result) = stream.next().await {
                match event_result {
                    Ok(LlmStreamEvent::Delta { content }) => {
                        delta_chunks.push(content);
                    }
                    Ok(LlmStreamEvent::ToolCall { tool_call: _ }) => {
                        // 工具调用事件暂不转发到 iOS
                    }
                    Ok(LlmStreamEvent::Finish { finish_reason: fr, usage: u }) => {
                        finish_reason = fr;
                        usage = u;
                    }
                    Ok(LlmStreamEvent::Error { message }) => {
                        yield Ok(AiStreamEvent::Error {
                            code: "ai.provider_stream_error".to_owned(),
                            message,
                            retryable: true,
                            blocked_reason: None,
                            safe_fallback_text: Some("暂时无法获取回答，请稍后重试。".to_owned()),
                        });
                        return;
                    }
                    Err(e) => {
                        let retryable = e.is_retryable();
                        yield Ok(AiStreamEvent::Error {
                            code: e.stable_code().to_owned(),
                            message: e.to_string(),
                            retryable,
                            blocked_reason: None,
                            safe_fallback_text: Some("暂时无法获取回答，请稍后重试。".to_owned()),
                        });
                        return;
                    }
                }
            }

            let accumulated_text = delta_chunks.concat();
            let package = context.fact_package.unwrap_or_else(AiFactPackage::empty);
            let verification = AiAnswerVerifier::new().verify(&accumulated_text, &package);

            if verification.is_blocked() {
                let final_text = verification
                    .safe_fallback_text
                    .clone()
                    .unwrap_or_else(|| "这次回答没有通过安全校验，请基于已确认事实重新提问。".to_owned());
                yield Ok(AiStreamEvent::Delta {
                    text: final_text.clone(),
                });
                yield Ok(AiStreamEvent::MessageCompleted {
                    message_id: context.message_id,
                    final_text,
                    usage,
                    finish_reason: LlmFinishReason::ContentFilter,
                    citations: Vec::new(),
                    verification,
                });
                return;
            }

            for text in delta_chunks {
                yield Ok(AiStreamEvent::Delta { text });
            }

            // 3. 发送 message_completed
            yield Ok(AiStreamEvent::MessageCompleted {
                message_id: context.message_id,
                final_text: accumulated_text,
                usage,
                finish_reason,
                citations: Vec::new(),
                verification,
            });
        }
        .boxed()
    }
}
