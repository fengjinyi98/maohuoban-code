use axum::response::{
    IntoResponse, Response,
    sse::{Event, KeepAlive, Sse},
};
use futures_util::stream;
use maohuoban_ai_domain::ai::{
    AiAnswerVerification, AiPetResolution, AiStreamEvent, LlmFinishReason, LlmUsage,
};
use uuid::Uuid;

use super::assistant_message_persistence::spawn_assistant_message_persist;

/// pet_resolution_stream_response 构建宠物解析未完成的安全 SSE 响应
/// 核心职责：
/// - 返回 pet_resolution 事件帮助前端展示选择或缺失信息
/// - 跳过主 Provider，避免在没有唯一宠物事实根时调用 LLM
pub(super) fn pet_resolution_stream_response(
    session_repo: std::sync::Arc<dyn maohuoban_ai_application::ai::ports::AiSessionRepository>,
    session_id: Uuid,
    message_id: Uuid,
    title: String,
    resolution: AiPetResolution,
) -> Response {
    let final_text = pet_resolution_message_text(&resolution).to_owned();
    spawn_assistant_message_persist(
        session_repo,
        message_id,
        session_id,
        final_text.clone(),
        0,
        0,
        "pet_resolution_skipped_main_agent".to_owned(),
    );

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
    let sse_stream = stream::iter(events.into_iter().map(|event| {
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
pub(super) fn pet_resolution_message_text(resolution: &AiPetResolution) -> &'static str {
    match resolution {
        AiPetResolution::NeedsSelection { .. } => "我需要先确认你想问哪只宠物。",
        AiPetResolution::UnauthorizedOrNotFound => "我没有找到你有权限访问的这只宠物。",
        AiPetResolution::NoPetContext => "请先创建或选择一只宠物，我再围绕它的记录继续回答。",
        AiPetResolution::Resolved { .. } => "已确认目标宠物。",
    }
}
