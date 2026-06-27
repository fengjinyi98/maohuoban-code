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
use futures_util::{StreamExt, stream};
use maohuoban_ai_application::ai::intent::AiIntentGate;
use maohuoban_ai_application::ai::ports::AiRequestGateLog;
use maohuoban_ai_domain::ai::{
    AiAnswerVerification, AiGateDecision, AiIntent, AiStreamEvent, LlmFinishReason, LlmUsage,
};
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};
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
    let gate_decision = AiIntentGate::new().classify(&req.message);

    persist_session_and_user_message(
        &state.session_repository,
        &req,
        actor_user_id,
        session_id,
        title.clone(),
        now,
    )
    .await;

    let _ = state
        .session_repository
        .insert_request_gate_log(&AiRequestGateLog {
            session_id: Some(session_id),
            actor_user_id,
            intent: intent_code(gate_decision.intent).to_owned(),
            gate_decision: gate_decision_code(&gate_decision).to_owned(),
            context_loaded: gate_decision.context_loaded,
            request_hash: request_hash(&req.message),
            resolved_pet_id: None,
            selected_pet_id: req.selected_pet_id,
            risk_signal: gate_decision.risk_signal.clone(),
            estimated_input_tokens: i32::try_from(req.message.chars().count()).unwrap_or(i32::MAX),
        })
        .await;

    if !gate_decision.context_loaded {
        return gated_stream_response(
            state.session_repository.clone(),
            session_id,
            message_id,
            title,
            &gate_decision,
        );
    }

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

/// gated_stream_response 构建不进入主 Agent 的安全 SSE 响应
/// 核心职责：
/// - 对 off-topic、app support 和风险请求跳过 Provider
/// - 输出稳定 message_started/message_completed 事件
fn gated_stream_response(
    session_repo: std::sync::Arc<dyn maohuoban_ai_application::ai::ports::AiSessionRepository>,
    session_id: Uuid,
    message_id: Uuid,
    title: String,
    gate_decision: &AiGateDecision,
) -> Response {
    let final_text = gated_message_text(gate_decision).to_owned();
    spawn_assistant_message_persist(
        session_repo,
        message_id,
        session_id,
        final_text.clone(),
        0,
        0,
        "gate_skipped_main_agent".to_owned(),
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
    let sse_stream = stream::iter(events.into_iter().map(|event| {
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
fn gated_message_text(gate_decision: &AiGateDecision) -> &'static str {
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

/// intent_code 返回审计用意图编码
/// 核心职责：
/// - 使用稳定 snake_case 字符串写入审计表
fn intent_code(intent: AiIntent) -> &'static str {
    match intent {
        AiIntent::PetCare => "pet_care",
        AiIntent::PetRecordQuery => "pet_record_query",
        AiIntent::PetFood => "pet_food",
        AiIntent::PetHealthRisk => "pet_health_risk",
        AiIntent::EmotionalPetContext => "emotional_pet_context",
        AiIntent::AppSupport => "app_support",
        AiIntent::OffTopic => "off_topic",
        AiIntent::PromptInjection => "prompt_injection",
        AiIntent::CostAbuse => "cost_abuse",
    }
}

/// gate_decision_code 返回审计用 gate 决策编码
/// 核心职责：
/// - 区分加载上下文、跳过主 Agent 和安全阻断
fn gate_decision_code(gate_decision: &AiGateDecision) -> &'static str {
    if !gate_decision.allow_processing() {
        "blocked"
    } else if gate_decision.context_loaded {
        "load_context"
    } else {
        "skip_main_agent"
    }
}

/// request_hash 生成审计用请求哈希
/// 核心职责：
/// - 避免审计表保存完整用户原文
fn request_hash(message: &str) -> String {
    let mut hasher = DefaultHasher::new();
    message.hash(&mut hasher);
    format!("{:016x}", hasher.finish())
}
