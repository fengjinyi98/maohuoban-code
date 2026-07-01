use axum::response::{
    IntoResponse, Response,
    sse::{Event, KeepAlive, Sse},
};
use chrono::Utc;
use futures_util::stream;
use maohuoban_ai_application::ai::ports::{ChatTurnTransactionPort, FinalizerTxInput};
use maohuoban_ai_domain::ai::{
    AiAnswerVerification, AiGateDecision, AiIntent, AiMessage, AiMessageRole, AiMessageStatus,
    AiSessionTurnStatus, AiStreamEvent, LlmFinishReason, LlmUsage,
};
use uuid::Uuid;

use super::super::super::diagnostics::record_chat_stream_event_emitted;

/// gated_stream_response 构建不进入主 Agent 的安全 SSE 响应
/// 核心职责：
/// - 对 off-topic、app support 和风险请求跳过 Provider
/// - 在单个事务内持久化边界消息和 turn 终态
/// - 输出稳定 message_started/message_completed 事件
pub(crate) fn gated_stream_response(
    chat_turn_transaction: std::sync::Arc<dyn ChatTurnTransactionPort>,
    session_id: Uuid,
    turn_id: Uuid,
    message_id: Uuid,
    title: String,
    gate_decision: &AiGateDecision,
) -> Response {
    let final_text = gated_message_text(gate_decision).to_owned();
    spawn_finalizer_tx(
        chat_turn_transaction,
        session_id,
        turn_id,
        message_id,
        final_text.clone(),
        "gate_skipped_main_agent",
    );

    let events = vec![
        AiStreamEvent::MessageStarted {
            chat_session_id: session_id,
            message_id,
            target_pet: None,
            title,
        },
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

/// gated_message_text 返回 gate 分支安全提示
/// 核心职责：
/// - 为非宠物和风险请求提供明确边界文案
pub(crate) fn gated_message_text(gate_decision: &AiGateDecision) -> &'static str {
    match gate_decision.intent {
        AiIntent::AppSupport => {
            "这个问题属于毛伙伴 App 使用帮助，我先不读取宠物事实。你可以描述遇到的页面或操作，我会按应用功能边界说明。"
        }
        AiIntent::PromptInjection | AiIntent::CostAbuse => {
            "这个请求不符合毛球助手的安全边界，我不能继续处理。"
        }
        _ => "我现在只能处理宠物照护、宠物记录和毛伙伴 App 相关问题。",
    }
}

/// spawn_finalizer_tx 异步在单个事务内持久化边界消息和 turn 终态
/// 核心职责：
/// - 在 gate / pet_resolution 分支统一收口 Finalizer 事务
/// - 避免终态更新散落在各 handler
pub(crate) fn spawn_finalizer_tx(
    chat_turn_transaction: std::sync::Arc<dyn ChatTurnTransactionPort>,
    session_id: Uuid,
    turn_id: Uuid,
    message_id: Uuid,
    final_text: String,
    finish_reason: &str,
) {
    let finish_reason = finish_reason.to_owned();
    tokio::spawn(async move {
        let assistant_message = AiMessage {
            id: message_id,
            session_id,
            turn_id: Some(turn_id),
            role: AiMessageRole::Assistant,
            content: final_text,
            status: AiMessageStatus::Completed,
            citations: Vec::new(),
            model: None,
            provider: None,
            finish_reason: Some(finish_reason.clone()),
            usage_input_tokens: Some(0),
            usage_output_tokens: Some(0),
            verification: Some(AiAnswerVerification::passed()),
            created_at: Utc::now(),
        };
        let _ = chat_turn_transaction
            .persist_finalizer_tx(&FinalizerTxInput {
                assistant_message: &assistant_message,
                citations: &[],
                turn_id,
                turn_status: AiSessionTurnStatus::Completed,
                assistant_message_id: Some(message_id),
                finish_reason: Some(&finish_reason),
                error_code: None,
                retryable: None,
            })
            .await;
    });
}
