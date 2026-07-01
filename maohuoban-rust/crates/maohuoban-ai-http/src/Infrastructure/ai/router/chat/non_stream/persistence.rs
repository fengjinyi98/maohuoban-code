//! persistence 非流式 Finalizer 持久化
//! 核心职责：
//! - 在单个事务内写入 assistant message、citations 并更新 turn 终态
//! - 边界分支 turn 的快速完成和持久化

use axum::response::Response;
use chrono::Utc;
use maohuoban_ai_application::ai::ports::FinalizerTxInput;
use maohuoban_ai_application::ai::stream::AiCompleteResult;
use maohuoban_ai_domain::ai::{
    AiAnswerVerification, AiMessage, AiMessageRole, AiMessageStatus, AiSessionTurnStatus,
    LlmFinishReason, LlmUsage,
};
use uuid::Uuid;

use super::super::super::AiHttpState;
use super::super::turn_preparation::ChatTurnContext;
use super::response::ChatCompleteResponse;
use crate::ai::response::ok_response;

/// persist_finalizer_tx 在单个事务内持久化 Finalizer 阶段全部数据
pub(super) async fn persist_finalizer_tx(
    state: &AiHttpState,
    message_id: Uuid,
    session_id: Uuid,
    turn_id: Uuid,
    complete: &AiCompleteResult,
) {
    let assistant_message = AiMessage {
        id: message_id,
        session_id,
        turn_id: Some(turn_id),
        role: AiMessageRole::Assistant,
        content: complete.final_text.clone(),
        status: AiMessageStatus::Completed,
        citations: complete.citations.iter().map(|c| c.source_id).collect(),
        model: Some(complete.model.clone()),
        provider: Some(complete.provider.clone()),
        finish_reason: Some(format!("{:?}", complete.finish_reason)),
        usage_input_tokens: Some(complete.usage.input_tokens),
        usage_output_tokens: Some(complete.usage.output_tokens),
        verification: Some(complete.verification.clone()),
        created_at: Utc::now(),
    };
    let finish_reason_str = format!("{:?}", complete.finish_reason);
    let _ = state
        .chat_turn_transaction
        .persist_finalizer_tx(&FinalizerTxInput {
            assistant_message: &assistant_message,
            citations: &complete.citations,
            turn_id,
            turn_status: AiSessionTurnStatus::Completed,
            assistant_message_id: Some(message_id),
            finish_reason: Some(&finish_reason_str),
            error_code: None,
            retryable: None,
        })
        .await;
}

/// complete_boundary_turn 完成边界分支 turn 并返回响应
pub(super) async fn complete_boundary_turn(
    state: &AiHttpState,
    context: &ChatTurnContext,
    message_text: String,
    finish_reason: &str,
) -> Response {
    let assistant_message = AiMessage {
        id: context.assistant_message_id,
        session_id: context.session_id,
        turn_id: Some(context.turn_id.as_uuid()),
        role: AiMessageRole::Assistant,
        content: message_text.clone(),
        status: AiMessageStatus::Completed,
        citations: Vec::new(),
        model: None,
        provider: None,
        finish_reason: Some(finish_reason.to_owned()),
        usage_input_tokens: Some(0),
        usage_output_tokens: Some(0),
        verification: Some(AiAnswerVerification::passed()),
        created_at: Utc::now(),
    };
    let _ = state
        .chat_turn_transaction
        .persist_finalizer_tx(&FinalizerTxInput {
            assistant_message: &assistant_message,
            citations: &[],
            turn_id: context.turn_id.as_uuid(),
            turn_status: AiSessionTurnStatus::Completed,
            assistant_message_id: Some(context.assistant_message_id),
            finish_reason: Some(finish_reason),
            error_code: None,
            retryable: None,
        })
        .await;
    ok_response(
        "ai.chat_completed",
        "AI 回答已完成",
        ChatCompleteResponse {
            chat_session_id: context.session_id,
            message_id: context.assistant_message_id,
            title: context.title.clone(),
            target_pet: context.target_pet.clone(),
            final_text: message_text,
            citations: Vec::new(),
            usage: LlmUsage::default(),
            finish_reason: LlmFinishReason::Stop,
            verification: AiAnswerVerification::passed(),
        },
    )
}
