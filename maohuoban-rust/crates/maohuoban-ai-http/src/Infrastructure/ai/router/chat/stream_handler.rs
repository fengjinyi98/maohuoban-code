use axum::{
    Json,
    extract::State,
    http::HeaderMap,
    response::{
        IntoResponse, Response,
        sse::{Event, KeepAlive, Sse},
    },
};
use chrono::Utc;
use futures_util::StreamExt;
use maohuoban_ai_domain::ai::AiStreamEvent;
use uuid::Uuid;

use super::super::AiHttpState;
use super::super::auth::current_user_id;
use super::assistant_message_persistence::spawn_assistant_message_persist;
use super::llm_request::build_llm_request;
use super::request::ChatStreamRequest;
use super::session_persistence::persist_session_and_user_message;
use super::title::build_title;
use crate::ai::response::unauthorized_response;

/// handle_chat_stream 流式聊天 SSE handler
/// 核心职责：
/// - 校验登录态并从 token 注入 actor
/// - 输出毛伙伴稳定 SSE 事件并持久化完成消息
pub async fn handle_chat_stream(
    State(state): State<AiHttpState>,
    headers: HeaderMap,
    Json(req): Json<ChatStreamRequest>,
) -> Response {
    let Ok(actor_user_id) = current_user_id(&state.auth, &headers).await else {
        return unauthorized_response();
    };

    let llm_request = build_llm_request(&req.message);
    let session_id = req.chat_session_id.unwrap_or_else(Uuid::new_v4);
    let message_id = Uuid::new_v4();
    let now = Utc::now();
    let title = build_title(&req.message);

    persist_session_and_user_message(
        &state.session_repository,
        &req,
        actor_user_id,
        session_id,
        title.clone(),
        now,
    )
    .await;

    let stream = state
        .stream_pipeline
        .run(llm_request, session_id, message_id, title);

    let session_repo = state.session_repository.clone();
    let sse_stream = stream.map(move |result| {
        let event = match result {
            Ok(e) => e,
            Err(err) => AiStreamEvent::Error {
                code: err.stable_code().to_owned(),
                message: err.to_string(),
                retryable: err.is_retryable(),
                blocked_reason: None,
                safe_fallback_text: Some("暂时无法获取回答，请稍后重试。".to_owned()),
            },
        };

        if let AiStreamEvent::MessageCompleted {
            final_text,
            usage,
            finish_reason,
            ..
        } = &event
        {
            spawn_assistant_message_persist(
                session_repo.clone(),
                message_id,
                session_id,
                final_text.clone(),
                usage.input_tokens,
                usage.output_tokens,
                format!("{finish_reason:?}"),
            );
        }

        let json = serde_json::to_string(&event).unwrap_or_else(|_| "{}".to_owned());
        Ok::<Event, std::convert::Infallible>(Event::default().event(event.event_name()).data(json))
    });

    Sse::new(sse_stream)
        .keep_alive(KeepAlive::default())
        .into_response()
}
