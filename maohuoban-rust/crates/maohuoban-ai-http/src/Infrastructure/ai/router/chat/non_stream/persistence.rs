//! persistence 非流式 Finalizer 持久化
//! 核心职责：
//! - 通过 TurnFinalizer 写入 assistant message、citations 并更新 turn 终态
//! - 边界分支 turn 的快速完成和持久化

use axum::response::Response;
use maohuoban_ai_application::ai::finalizer::{
    FinalizationReceipt, FinalizerStore, TurnFinalizer, TurnTerminalOutput,
};
use maohuoban_ai_application::ai::stream::AiCompleteResult;
use maohuoban_ai_domain::ai::{
    AiAnswerVerification, AiResult, AiSessionTurnStatus, LlmFinishReason, LlmUsage,
};
use std::sync::Arc;
use uuid::Uuid;

use super::super::super::AiHttpState;
use super::super::super::diagnostics::record_chat_finalizer_completed;
use super::super::persistence::finalizer_store::HttpFinalizerStore;
use super::super::turn_preparation::ChatTurnContext;
use super::response::ChatCompleteResponse;
use crate::ai::response::{ai_error_response, ok_response};

/// persist_finalizer 通过 Finalizer 持久化终态数据
pub(super) async fn persist_finalizer(
    state: &AiHttpState,
    actor_user_id: Uuid,
    message_id: Uuid,
    session_id: Uuid,
    turn_id: Uuid,
    complete: &AiCompleteResult,
) -> AiResult<()> {
    let store = Arc::new(HttpFinalizerStore::from_state(state));
    let receipt = finalize_complete_turn(
        store,
        actor_user_id,
        message_id,
        session_id,
        turn_id,
        complete,
    )
    .await?;
    record_chat_finalizer_completed(session_id, turn_id, Some(message_id), &receipt);
    Ok(())
}

/// finalize_complete_turn 完成非流式主路径终态收口
/// 核心职责：
/// - 通过传入的 FinalizerStore 执行关键同步写入
/// - 将 Finalizer fail-closed 错误原样返回给 handler
pub(super) async fn finalize_complete_turn(
    store: Arc<dyn FinalizerStore>,
    actor_user_id: Uuid,
    message_id: Uuid,
    session_id: Uuid,
    turn_id: Uuid,
    complete: &AiCompleteResult,
) -> AiResult<FinalizationReceipt> {
    TurnFinalizer::new(store)
        .finalize(TurnTerminalOutput {
            turn_id,
            session_id,
            actor_user_id,
            assistant_message_id: message_id,
            status: AiSessionTurnStatus::Completed,
            final_text: Some(complete.final_text.clone()),
            content_blocks: complete.content_blocks.clone(),
            safe_failure_text: None,
            failure_code: None,
            retryable: None,
            provider: Some(complete.provider.clone()),
            model: Some(complete.model.clone()),
            finish_reason: Some(complete.finish_reason),
            usage: complete.usage,
            verification: Some(complete.verification.clone()),
            citations: complete.citations.clone(),
            proposed_actions: Vec::new(),
            async_jobs: Vec::new(),
        })
        .await
}

/// complete_boundary_turn 完成边界分支 turn 并返回响应
pub(super) async fn complete_boundary_turn(
    state: &AiHttpState,
    actor_user_id: Uuid,
    context: &ChatTurnContext,
    message_text: String,
    _finish_reason: &str,
) -> Response {
    let store = Arc::new(HttpFinalizerStore::from_state(state));
    let receipt = TurnFinalizer::new(store)
        .finalize(TurnTerminalOutput {
            turn_id: context.turn_id.as_uuid(),
            session_id: context.session_id,
            actor_user_id,
            assistant_message_id: context.assistant_message_id,
            status: AiSessionTurnStatus::Completed,
            final_text: Some(message_text.clone()),
            content_blocks: Vec::new(),
            safe_failure_text: None,
            failure_code: None,
            retryable: None,
            provider: None,
            model: None,
            finish_reason: Some(LlmFinishReason::Stop),
            usage: LlmUsage::default(),
            verification: Some(AiAnswerVerification::passed()),
            citations: Vec::new(),
            proposed_actions: Vec::new(),
            async_jobs: Vec::new(),
        })
        .await;
    let receipt = match receipt {
        Ok(receipt) => receipt,
        Err(error) => return ai_error_response(&error),
    };
    record_chat_finalizer_completed(
        context.session_id,
        context.turn_id.as_uuid(),
        Some(context.assistant_message_id),
        &receipt,
    );
    ok_response(
        "ai.chat_completed",
        "AI 回答已完成",
        ChatCompleteResponse {
            chat_session_id: context.session_id,
            message_id: context.assistant_message_id,
            title: context.title.clone(),
            target_pet: context.target_pet.clone(),
            final_text: message_text,
            content_blocks: Vec::new(),
            citations: Vec::new(),
            usage: LlmUsage::default(),
            finish_reason: LlmFinishReason::Stop,
            verification: AiAnswerVerification::passed(),
        },
    )
}
