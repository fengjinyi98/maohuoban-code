use axum::response::{
    IntoResponse, Response,
    sse::{Event, KeepAlive, Sse},
};
use futures_util::StreamExt;
use uuid::Uuid;

use maohuoban_ai_domain::ai::AiStreamEvent;

use super::super::super::diagnostics::{
    record_chat_provider_error, record_chat_stream_event_emitted,
};
use super::super::persistence::assistant_message_persistence::{
    AssistantMessagePersistRequest, persist_assistant_message,
};

const EMPTY_MODEL_OUTPUT_FALLBACK_TEXT: &str = "暂时无法获取回答，请稍后重试。";

pub(crate) fn provider_stream_response<S>(
    stream: S,
    session_repo: std::sync::Arc<dyn maohuoban_ai_application::ai::ports::AiSessionRepository>,
    session_id: Uuid,
    message_id: Uuid,
    engine_mode: &'static str,
) -> Response
where
    S: futures_util::Stream<Item = Result<AiStreamEvent, maohuoban_ai_domain::ai::AiError>>
        + Send
        + 'static,
{
    let sse_stream = stream.then(move |result| {
        let session_repo = session_repo.clone();
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
                persist_assistant_message(
                    &session_repo,
                    AssistantMessagePersistRequest::new(
                        message_id,
                        session_id,
                        final_text.clone(),
                        citations.clone(),
                        usage.input_tokens,
                        usage.output_tokens,
                        format!("{finish_reason:?}"),
                    ),
                )
                .await;
            }

            if let AiStreamEvent::ProposedAction { action } = &event {
                let repo = session_repo.clone();
                let mut action = action.clone();
                if action.source_message_id.is_none() {
                    action.source_message_id = Some(message_id);
                }
                tokio::spawn(async move {
                    let _ = repo.insert_proposed_action(session_id, &action).await;
                });
            }

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
