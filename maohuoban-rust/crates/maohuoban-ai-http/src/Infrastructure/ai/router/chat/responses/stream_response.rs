use axum::response::{
    IntoResponse, Response,
    sse::{Event, KeepAlive, Sse},
};
use chrono::Utc;
use futures_util::StreamExt;
use uuid::Uuid;

use maohuoban_ai_application::ai::ports::ChatTurnTransactionPort;
use maohuoban_ai_application::ai::ports::FinalizerTxInput;
use maohuoban_ai_domain::ai::{
    AiMessage, AiMessageRole, AiMessageStatus, AiSessionTurnStatus, AiStreamEvent,
};

use super::super::super::diagnostics::{
    record_chat_provider_error, record_chat_stream_event_emitted,
};

const EMPTY_MODEL_OUTPUT_FALLBACK_TEXT: &str = "暂时无法获取回答，请稍后重试。";

pub(crate) fn provider_stream_response<S>(
    stream: S,
    chat_turn_transaction: std::sync::Arc<dyn ChatTurnTransactionPort>,
    session_id: Uuid,
    message_id: Uuid,
    turn_id: Uuid,
    engine_mode: &'static str,
) -> Response
where
    S: futures_util::Stream<Item = Result<AiStreamEvent, maohuoban_ai_domain::ai::AiError>>
        + Send
        + 'static,
{
    let sse_stream = stream.then(move |result| {
        let chat_turn_transaction = chat_turn_transaction.clone();
        async move {
            let event = match result {
                Ok(event) => event,
                Err(err) => AiStreamEvent::Error {
                    code: err.stable_code().to_owned(),
                    message: err.user_visible_message().to_owned(),
                    retryable: err.is_retryable(),
                    blocked_reason: None,
                    safe_fallback_text: Some("暂时无法获取回答，请稍后重试。".to_owned()),
                },
            };
            let event = normalize_stream_completion_event(event);

            if let AiStreamEvent::Error {
                code,
                retryable,
                safe_fallback_text,
                ..
            } = &event
            {
                record_chat_provider_error(
                    session_id,
                    engine_mode,
                    code,
                    *retryable,
                    safe_fallback_text.as_deref(),
                );
            }

            if let AiStreamEvent::MessageCompleted {
                final_text,
                usage,
                finish_reason,
                citations,
                ..
            }
            | AiStreamEvent::AnswerCompleted {
                final_text,
                usage,
                finish_reason,
                citations,
                ..
            } = &event
            {
                let assistant_message = AiMessage {
                    id: message_id,
                    session_id,
                    turn_id: Some(turn_id),
                    role: AiMessageRole::Assistant,
                    content: final_text.clone(),
                    status: AiMessageStatus::Completed,
                    citations: citations.iter().map(|c| c.source_id).collect(),
                    model: Some("default".to_owned()),
                    provider: Some("fake".to_owned()),
                    finish_reason: Some(format!("{finish_reason:?}")),
                    usage_input_tokens: Some(usage.input_tokens),
                    usage_output_tokens: Some(usage.output_tokens),
                    verification: None,
                    created_at: Utc::now(),
                };
                let finish_reason_str = format!("{finish_reason:?}");
                let _ = chat_turn_transaction
                    .persist_finalizer_tx(&FinalizerTxInput {
                        assistant_message: &assistant_message,
                        citations,
                        turn_id,
                        turn_status: AiSessionTurnStatus::Completed,
                        assistant_message_id: Some(message_id),
                        finish_reason: Some(&finish_reason_str),
                        error_code: None,
                        retryable: None,
                    })
                    .await;
            }

            // proposed actions 仍通过 session_repository 异步写入，
            // 不在 Finalizer Tx 范围内
            if let AiStreamEvent::ProposedAction { .. } = &event {}

            record_chat_stream_event_emitted(session_id, &event);
            let json = serde_json::to_string(&event).unwrap_or_else(|_| "{}".to_owned());
            Ok::<Event, std::convert::Infallible>(
                Event::default().event(event.event_name()).data(json),
            )
        }
    });

    Sse::new(sse_stream)
        .keep_alive(KeepAlive::default())
        .into_response()
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
