use axum::response::{
    IntoResponse, Response,
    sse::{Event, KeepAlive, Sse},
};
use futures_util::StreamExt;
use std::sync::Arc;
use uuid::Uuid;

use maohuoban_ai_application::ai::finalizer::{
    FinalizerAsyncJob, FinalizerAsyncJobKind, FinalizerStore, TurnFinalizer, TurnTerminalOutput,
};
use maohuoban_ai_domain::ai::{
    AiError, AiProposedAction, AiSessionTurnStatus, AiStreamEvent, LlmFinishReason, LlmUsage,
};

use super::super::super::diagnostics::{
    record_chat_finalizer_completed, record_chat_provider_error, record_chat_stream_event_emitted,
};

const EMPTY_MODEL_OUTPUT_FALLBACK_TEXT: &str = "暂时无法获取回答，请稍后重试。";

/// StreamFinalizerContext 流式 Finalizer 上下文
/// 核心职责：
/// - 持有流式终态收口所需的关联键和共享状态
/// - 缓存完成事件前到达的 proposed action
#[derive(Clone)]
struct StreamFinalizerContext {
    finalizer_store: Arc<dyn FinalizerStore>,
    proposed_actions: Arc<tokio::sync::Mutex<Vec<AiProposedAction>>>,
    session_id: Uuid,
    actor_user_id: Uuid,
    message_id: Uuid,
    turn_id: Uuid,
    engine_mode: &'static str,
}

pub(crate) fn provider_stream_response<S>(
    stream: S,
    finalizer_store: Arc<dyn FinalizerStore>,
    session_id: Uuid,
    actor_user_id: Uuid,
    message_id: Uuid,
    turn_id: Uuid,
    engine_mode: &'static str,
) -> Response
where
    S: futures_util::Stream<Item = Result<AiStreamEvent, maohuoban_ai_domain::ai::AiError>>
        + Send
        + 'static,
{
    let context = StreamFinalizerContext {
        finalizer_store,
        proposed_actions: Arc::new(tokio::sync::Mutex::new(Vec::<AiProposedAction>::new())),
        session_id,
        actor_user_id,
        message_id,
        turn_id,
        engine_mode,
    };
    let sse_stream = stream.then(move |result| {
        let context = context.clone();
        async move { project_stream_result(result, &context).await }
    });

    Sse::new(sse_stream)
        .keep_alive(KeepAlive::default())
        .into_response()
}

async fn project_stream_result(
    result: Result<AiStreamEvent, AiError>,
    context: &StreamFinalizerContext,
) -> Result<Event, std::convert::Infallible> {
    let event = normalize_stream_completion_event(stream_result_to_event(result));
    remember_proposed_action(&event, context).await;
    finalize_error_if_needed(&event, context).await;
    finalize_completed_if_needed(&event, context).await;
    finalize_confirmation_if_needed(&event, context).await;
    record_chat_stream_event_emitted(context.session_id, &event);
    Ok(event_to_sse(&event))
}

fn stream_result_to_event(result: Result<AiStreamEvent, AiError>) -> AiStreamEvent {
    match result {
        Ok(event) => event,
        Err(err) => AiStreamEvent::Error {
            code: err.stable_code().to_owned(),
            message: err.user_visible_message().to_owned(),
            retryable: err.is_retryable(),
            blocked_reason: None,
            safe_fallback_text: Some("暂时无法获取回答，请稍后重试。".to_owned()),
        },
    }
}

async fn remember_proposed_action(event: &AiStreamEvent, context: &StreamFinalizerContext) {
    if let AiStreamEvent::ProposedAction { action } = event {
        context.proposed_actions.lock().await.push(action.clone());
    }
}

async fn finalize_error_if_needed(event: &AiStreamEvent, context: &StreamFinalizerContext) {
    let AiStreamEvent::Error {
        code,
        retryable,
        safe_fallback_text,
        ..
    } = event
    else {
        return;
    };
    record_chat_provider_error(
        context.session_id,
        context.engine_mode,
        code,
        *retryable,
        safe_fallback_text.as_deref(),
    );
    let safe_text = safe_fallback_text
        .clone()
        .unwrap_or_else(|| "暂时无法获取回答，请稍后重试。".to_owned());
    let receipt = TurnFinalizer::new(context.finalizer_store.clone())
        .finalize(TurnTerminalOutput {
            turn_id: context.turn_id,
            session_id: context.session_id,
            actor_user_id: context.actor_user_id,
            assistant_message_id: context.message_id,
            status: AiSessionTurnStatus::Failed,
            final_text: None,
            content_blocks: Vec::new(),
            safe_failure_text: Some(safe_text),
            failure_code: Some(code.clone()),
            retryable: Some(*retryable),
            provider: Some(context.engine_mode.to_owned()),
            model: None,
            finish_reason: Some(LlmFinishReason::Error),
            usage: LlmUsage::default(),
            verification: None,
            citations: Vec::new(),
            proposed_actions: Vec::new(),
            async_jobs: Vec::new(),
        })
        .await;
    record_finalizer_receipt(context, Some(context.message_id), receipt);
}

async fn finalize_completed_if_needed(event: &AiStreamEvent, context: &StreamFinalizerContext) {
    let (final_text, content_blocks, usage, finish_reason, citations, verification) = match event {
        AiStreamEvent::MessageCompleted {
            final_text,
            content_blocks,
            usage,
            finish_reason,
            citations,
            verification,
            ..
        }
        | AiStreamEvent::AnswerCompleted {
            final_text,
            content_blocks,
            usage,
            finish_reason,
            citations,
            verification,
            ..
        } => (
            final_text,
            content_blocks,
            usage,
            finish_reason,
            citations,
            verification,
        ),
        _ => return,
    };
    let actions = context.proposed_actions.lock().await.clone();
    let receipt = TurnFinalizer::new(context.finalizer_store.clone())
        .finalize(TurnTerminalOutput {
            turn_id: context.turn_id,
            session_id: context.session_id,
            actor_user_id: context.actor_user_id,
            assistant_message_id: context.message_id,
            status: AiSessionTurnStatus::Completed,
            final_text: Some(final_text.clone()),
            content_blocks: content_blocks.clone(),
            safe_failure_text: None,
            failure_code: None,
            retryable: None,
            provider: Some(context.engine_mode.to_owned()),
            model: None,
            finish_reason: Some(*finish_reason),
            usage: *usage,
            verification: Some(verification.clone()),
            citations: citations.clone(),
            proposed_actions: actions,
            async_jobs: vec![
                FinalizerAsyncJob::new(FinalizerAsyncJobKind::SessionSummary),
                FinalizerAsyncJob::new(FinalizerAsyncJobKind::MemoryCandidate),
            ],
        })
        .await;
    record_finalizer_receipt(context, Some(context.message_id), receipt);
}

async fn finalize_confirmation_if_needed(event: &AiStreamEvent, context: &StreamFinalizerContext) {
    if !matches!(event, AiStreamEvent::ConfirmationTask { .. }) {
        return;
    }
    let actions = context.proposed_actions.lock().await.clone();
    let receipt = TurnFinalizer::new(context.finalizer_store.clone())
        .finalize(TurnTerminalOutput {
            turn_id: context.turn_id,
            session_id: context.session_id,
            actor_user_id: context.actor_user_id,
            assistant_message_id: context.message_id,
            status: AiSessionTurnStatus::RequiresConfirmation,
            final_text: None,
            content_blocks: Vec::new(),
            safe_failure_text: None,
            failure_code: None,
            retryable: None,
            provider: Some(context.engine_mode.to_owned()),
            model: None,
            finish_reason: None,
            usage: LlmUsage::default(),
            verification: None,
            citations: Vec::new(),
            proposed_actions: actions,
            async_jobs: Vec::new(),
        })
        .await;
    record_finalizer_receipt(context, None, receipt);
}

fn record_finalizer_receipt(
    context: &StreamFinalizerContext,
    message_id: Option<Uuid>,
    receipt: Result<maohuoban_ai_application::ai::finalizer::FinalizationReceipt, AiError>,
) {
    if let Ok(receipt) = receipt {
        record_chat_finalizer_completed(context.session_id, context.turn_id, message_id, &receipt);
    }
}

fn event_to_sse(event: &AiStreamEvent) -> Event {
    let event_name = event.event_name();
    let json = serde_json::to_string(&event).unwrap_or_else(|_| "{}".to_owned());
    Event::default().event(event_name).data(json)
}

fn normalize_stream_completion_event(event: AiStreamEvent) -> AiStreamEvent {
    let (AiStreamEvent::MessageCompleted { final_text, .. }
    | AiStreamEvent::AnswerCompleted { final_text, .. }) = &event
    else {
        return event;
    };

    if final_text.trim().is_empty() {
        return AiStreamEvent::Error {
            code: "ai.provider.invalid_response".to_owned(),
            message: EMPTY_MODEL_OUTPUT_FALLBACK_TEXT.to_owned(),
            retryable: true,
            blocked_reason: None,
            safe_fallback_text: Some(EMPTY_MODEL_OUTPUT_FALLBACK_TEXT.to_owned()),
        };
    }

    event
}
