use axum::response::{
    IntoResponse, Response,
    sse::{Event, KeepAlive, Sse},
};
use futures_util::stream;
use maohuoban_ai_application::ai::finalizer::FinalizerStore;
use maohuoban_ai_domain::ai::{
    AiAnswerVerification, AiPetResolution, AiStreamEvent, LlmFinishReason, LlmUsage,
};
use uuid::Uuid;

use super::super::super::diagnostics::{
    record_chat_finalizer_completed, record_chat_stream_event_emitted,
};
use super::gated_stream_response::finalize_boundary_turn;
use crate::ai::response::ai_error_response;

/// pet_resolution_stream_response 构建宠物解析未完成的安全 SSE 响应
/// 核心职责：
/// - 返回 pet_resolution 事件帮助前端展示选择或缺失信息
/// - 跳过主 Provider，避免在没有唯一宠物事实根时调用 LLM
/// - 通过 Finalizer 持久化边界消息和 turn 终态
pub(crate) async fn pet_resolution_stream_response(
    finalizer_store: std::sync::Arc<dyn FinalizerStore>,
    session_id: Uuid,
    actor_user_id: Uuid,
    turn_id: Uuid,
    message_id: Uuid,
    title: String,
    resolution: AiPetResolution,
) -> Response {
    let final_text = pet_resolution_message_text(&resolution).to_owned();
    let receipt = finalize_boundary_turn(
        finalizer_store,
        session_id,
        actor_user_id,
        turn_id,
        message_id,
        final_text.clone(),
        "pet_resolution_skipped_main_agent",
    )
    .await;
    let receipt = match receipt {
        Ok(receipt) => receipt,
        Err(error) => return ai_error_response(&error),
    };
    record_chat_finalizer_completed(session_id, turn_id, Some(message_id), &receipt);

    let events = vec![
        AiStreamEvent::MessageStarted {
            chat_session_id: session_id,
            message_id,
            target_pet: None,
            title,
        },
        AiStreamEvent::PetResolution { resolution },
        AiStreamEvent::MessageCompleted {
            message_id,
            final_text,
            usage: LlmUsage::default(),
            finish_reason: LlmFinishReason::Stop,
            citations: vec![],
            verification: AiAnswerVerification::passed(),
        },
    ];
    let sse_stream = stream::iter(events.into_iter().map(move |event| {
        record_chat_stream_event_emitted(session_id, &event);
        let json = serde_json::to_string(&event).unwrap_or_else(|_| "{}".to_owned());
        Ok::<Event, std::convert::Infallible>(Event::default().event(event.event_name()).data(json))
    }));

    Sse::new(sse_stream)
        .keep_alive(KeepAlive::default())
        .into_response()
}

/// pet_resolution_message_text 返回宠物解析分支安全提示
/// 核心职责：
/// - 为无宠物、歧义和未授权场景提供不泄漏隐私的文案
pub(crate) fn pet_resolution_message_text(resolution: &AiPetResolution) -> &'static str {
    match resolution {
        AiPetResolution::NeedsSelection { .. } => "我需要先确认你想问哪只宠物。",
        AiPetResolution::UnauthorizedOrNotFound => "我没有找到你有权限访问的这只宠物。",
        AiPetResolution::NoPetContext => "请先创建或选择一只宠物，我再围绕它的记录继续回答。",
        AiPetResolution::Resolved { .. } => "已确认目标宠物。",
    }
}
