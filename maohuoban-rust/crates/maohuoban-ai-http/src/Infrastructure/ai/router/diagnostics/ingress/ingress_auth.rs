use maohuoban_ai_application::ai::diagnostics::{
    AiDiagnosticsCorrelation, redact_ai_diagnostics_text,
};
use maohuoban_ai_domain::ai::AiConversationSurface;
use maohuoban_diagnostics::Severity;
use serde_json::json;
use uuid::Uuid;

use super::super::diagnostics_common::{length_bucket, record_ai_event, surface_code, uuid_prefix};
use super::helpers::{record_chat_auth_result, record_chat_ingress_received};

/// record_chat_stream_ingress_received 记录流式入口到达
/// 核心职责：
/// - 在鉴权前记录 AI stream 请求已到达后端
/// - 为鉴权短路场景补齐 AI 专项观测点
pub(crate) fn record_chat_stream_ingress_received(
    chat_session_id: Option<Uuid>,
    selected_pet_id: Option<Uuid>,
    surface: AiConversationSurface,
    message: &str,
) {
    record_chat_ingress_received(
        "ai.chat.stream.ingress.received",
        chat_session_id,
        selected_pet_id,
        surface,
        message,
    );
}

/// record_chat_stream_request_received 记录流式聊天请求入口
/// 核心职责：
/// - 标记后端已接收到当前用户的 AI stream 请求
/// - 只保留脱敏 ID、入口 surface 和消息长度分桶
pub(crate) fn record_chat_stream_request_received(
    actor_user_id: Uuid,
    session_id: Uuid,
    message_id: Uuid,
    selected_pet_id: Option<Uuid>,
    surface: AiConversationSurface,
    message: &str,
) {
    let mut metadata = AiDiagnosticsCorrelation::for_session(session_id)
        .with_message_id(message_id)
        .to_metadata();
    metadata.extend(vec![
        (
            "actor_user_id_prefix",
            json!(uuid_prefix(Some(actor_user_id))),
        ),
        (
            "selected_pet_id_prefix",
            json!(uuid_prefix(selected_pet_id)),
        ),
        ("surface", json!(surface_code(surface))),
        ("message", json!(redact_ai_diagnostics_text(message))),
        (
            "message_length_bucket",
            json!(length_bucket(message.chars().count())),
        ),
        ("has_selected_pet", json!(selected_pet_id.is_some())),
    ]);
    record_ai_event("ai.chat.stream.request.received", Severity::Info, metadata);
}

/// record_chat_stream_auth_succeeded 记录流式入口鉴权成功
pub(crate) fn record_chat_stream_auth_succeeded(
    actor_user_id: Uuid,
    chat_session_id: Option<Uuid>,
    selected_pet_id: Option<Uuid>,
    surface: AiConversationSurface,
    message: &str,
) {
    record_chat_auth_result(
        "ai.chat.stream.auth.succeeded",
        Severity::Info,
        Some(actor_user_id),
        chat_session_id,
        selected_pet_id,
        surface,
        message,
        None,
        None,
        None,
    );
}

/// record_chat_stream_auth_failed 记录流式入口鉴权失败
pub(crate) fn record_chat_stream_auth_failed(
    chat_session_id: Option<Uuid>,
    selected_pet_id: Option<Uuid>,
    surface: AiConversationSurface,
    message: &str,
    has_authorization: bool,
    bearer_prefix_present: bool,
    error_code: &str,
) {
    record_chat_auth_result(
        "ai.chat.stream.auth.failed",
        Severity::Error,
        None,
        chat_session_id,
        selected_pet_id,
        surface,
        message,
        Some(has_authorization),
        Some(bearer_prefix_present),
        Some(error_code),
    );
}

/// record_chat_non_stream_ingress_received 记录非流式入口到达
pub(crate) fn record_chat_non_stream_ingress_received(
    chat_session_id: Option<Uuid>,
    selected_pet_id: Option<Uuid>,
    surface: AiConversationSurface,
    message: &str,
) {
    record_chat_ingress_received(
        "ai.chat.non_stream.ingress.received",
        chat_session_id,
        selected_pet_id,
        surface,
        message,
    );
}

/// record_chat_non_stream_auth_succeeded 记录非流式入口鉴权成功
pub(crate) fn record_chat_non_stream_auth_succeeded(
    actor_user_id: Uuid,
    chat_session_id: Option<Uuid>,
    selected_pet_id: Option<Uuid>,
    surface: AiConversationSurface,
    message: &str,
) {
    record_chat_auth_result(
        "ai.chat.non_stream.auth.succeeded",
        Severity::Info,
        Some(actor_user_id),
        chat_session_id,
        selected_pet_id,
        surface,
        message,
        None,
        None,
        None,
    );
}

/// record_chat_non_stream_auth_failed 记录非流式入口鉴权失败
pub(crate) fn record_chat_non_stream_auth_failed(
    chat_session_id: Option<Uuid>,
    selected_pet_id: Option<Uuid>,
    surface: AiConversationSurface,
    message: &str,
    has_authorization: bool,
    bearer_prefix_present: bool,
    error_code: &str,
) {
    record_chat_auth_result(
        "ai.chat.non_stream.auth.failed",
        Severity::Error,
        None,
        chat_session_id,
        selected_pet_id,
        surface,
        message,
        Some(has_authorization),
        Some(bearer_prefix_present),
        Some(error_code),
    );
}
