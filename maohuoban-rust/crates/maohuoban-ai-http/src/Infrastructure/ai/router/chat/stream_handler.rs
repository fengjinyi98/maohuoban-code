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
use maohuoban_ai_application::ai::ports::{AiRequestGateLog, AiToolAccessLog};
use maohuoban_ai_domain::ai::{
    AiAnswerVerification, AiGateDecision, AiIntent, AiPetDisplaySnapshot, AiPetResolution,
    AiStreamEvent, AiToolCallStatus, LlmFinishReason, LlmUsage,
};
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};
use uuid::Uuid;

use super::super::AiHttpState;
use super::super::auth::current_user_id;
use super::assistant_message_persistence::spawn_assistant_message_persist;
use super::llm_request::build_llm_request;
use super::request::ChatStreamRequest;
use super::session_persistence::{PetSessionContext, persist_session_and_user_message};
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

    let pet_resolution = if gate_decision.context_loaded {
        state
            .pet_resolver
            .resolve(&req.message, req.selected_pet_id, actor_user_id)
            .await
            .ok()
    } else {
        None
    };
    let resolved_pet_id = pet_resolution
        .as_ref()
        .and_then(AiPetResolution::resolved_pet_id);
    let target_pet = resolved_pet_snapshot(pet_resolution.as_ref());

    persist_session_and_user_message(
        &state.session_repository,
        &req,
        actor_user_id,
        session_id,
        title.clone(),
        PetSessionContext {
            primary_pet_id: resolved_pet_id.or(req.selected_pet_id),
            pet_display_snapshot: target_pet.clone(),
        },
        now,
    )
    .await;

    insert_request_gate_log(
        &state.session_repository,
        &req,
        session_id,
        actor_user_id,
        resolved_pet_id,
        &gate_decision,
    )
    .await;

    let initial_events = if gate_decision.context_loaded {
        insert_pet_catalog_tool_log(
            &state.session_repository,
            session_id,
            actor_user_id,
            resolved_pet_id,
            req.selected_pet_id,
            pet_resolution.as_ref(),
        )
        .await
    } else {
        Vec::new()
    };

    if !gate_decision.context_loaded {
        return gated_stream_response(
            state.session_repository.clone(),
            session_id,
            message_id,
            title,
            &gate_decision,
        );
    }

    if let Some(resolution) = pet_resolution
        .as_ref()
        .filter(|resolution| !resolution.is_resolved())
    {
        return pet_resolution_stream_response(
            state.session_repository.clone(),
            session_id,
            message_id,
            title,
            resolution.clone(),
        );
    }

    let stream = state
        .stream_pipeline
        .run_with_target_pet_and_initial_events(
            llm_request,
            session_id,
            message_id,
            title,
            target_pet,
            initial_events,
        );

    provider_stream_response(
        stream,
        state.session_repository.clone(),
        session_id,
        message_id,
    )
}

/// insert_request_gate_log 写入请求 gate 审计
/// 核心职责：
/// - 持久化意图、上下文加载状态和宠物解析结果
/// - 避免在主 handler 中展开审计表字段细节
async fn insert_request_gate_log(
    session_repo: &std::sync::Arc<dyn maohuoban_ai_application::ai::ports::AiSessionRepository>,
    req: &ChatStreamRequest,
    session_id: Uuid,
    actor_user_id: Uuid,
    resolved_pet_id: Option<Uuid>,
    gate_decision: &AiGateDecision,
) {
    let _ = session_repo
        .insert_request_gate_log(&AiRequestGateLog {
            session_id: Some(session_id),
            actor_user_id,
            intent: intent_code(gate_decision.intent).to_owned(),
            gate_decision: gate_decision_code(gate_decision).to_owned(),
            context_loaded: gate_decision.context_loaded,
            request_hash: request_hash(&req.message),
            resolved_pet_id,
            selected_pet_id: req.selected_pet_id,
            risk_signal: gate_decision.risk_signal.clone(),
            estimated_input_tokens: i32::try_from(req.message.chars().count()).unwrap_or(i32::MAX),
        })
        .await;
}

/// insert_pet_catalog_tool_log 写入授权宠物候选工具审计
/// 核心职责：
/// - 记录 list_authorized_pet_candidates 工具读取
/// - 为解析成功的请求返回 tool_call 初始事件
async fn insert_pet_catalog_tool_log(
    session_repo: &std::sync::Arc<dyn maohuoban_ai_application::ai::ports::AiSessionRepository>,
    session_id: Uuid,
    actor_user_id: Uuid,
    resolved_pet_id: Option<Uuid>,
    selected_pet_id: Option<Uuid>,
    pet_resolution: Option<&AiPetResolution>,
) -> Vec<AiStreamEvent> {
    let allowed = pet_resolution.is_some_and(AiPetResolution::is_resolved);
    let target_pet_id = resolved_pet_id.or(selected_pet_id);
    let returned_ref_ids = if allowed {
        target_pet_id
            .map(|id| vec![id.to_string()])
            .unwrap_or_default()
    } else {
        vec![]
    };
    let denied_reason = pet_resolution.and_then(pet_resolution_denied_reason);

    let _ = session_repo
        .insert_tool_access_log(&AiToolAccessLog {
            session_id: Some(session_id),
            actor_user_id,
            tool_name: "list_authorized_pet_candidates".to_owned(),
            requested_scope: "actor_pet_candidates".to_owned(),
            target_pet_id,
            allowed,
            denied_reason,
            returned_ref_ids,
            duration_ms: 0,
            risk_signal: None,
        })
        .await;

    if allowed {
        vec![AiStreamEvent::ToolCall {
            tool_name: "list_authorized_pet_candidates".to_owned(),
            status: AiToolCallStatus::Allowed,
            citation_count: 0,
        }]
    } else {
        Vec::new()
    }
}

/// pet_resolution_denied_reason 返回工具审计拒绝原因
/// 核心职责：
/// - 使用稳定原因码记录解析未完成原因
fn pet_resolution_denied_reason(resolution: &AiPetResolution) -> Option<String> {
    match resolution {
        AiPetResolution::Resolved { .. } => None,
        AiPetResolution::NeedsSelection { .. } => Some("needs_pet_selection".to_owned()),
        AiPetResolution::UnauthorizedOrNotFound => Some("unauthorized_or_not_found".to_owned()),
        AiPetResolution::NoPetContext => Some("no_pet_context".to_owned()),
    }
}

/// provider_stream_response 构建 Provider 流式响应
/// 核心职责：
/// - 将 AiStreamEvent 转换为 SSE Event
/// - 在 message_completed 时持久化助手消息
fn provider_stream_response<S>(
    stream: S,
    session_repo: std::sync::Arc<dyn maohuoban_ai_application::ai::ports::AiSessionRepository>,
    session_id: Uuid,
    message_id: Uuid,
) -> Response
where
    S: futures_util::Stream<Item = Result<AiStreamEvent, maohuoban_ai_domain::ai::AiError>>
        + Send
        + 'static,
{
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

/// pet_resolution_stream_response 构建宠物解析未完成的安全 SSE 响应
/// 核心职责：
/// - 返回 pet_resolution 事件帮助前端展示选择或缺失信息
/// - 跳过主 Provider，避免在没有唯一宠物事实根时调用 LLM
fn pet_resolution_stream_response(
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

/// resolved_pet_snapshot 提取已解析宠物快照
/// 核心职责：
/// - 只在 AiPetResolution::Resolved 时返回后端宠物展示快照
fn resolved_pet_snapshot(pet_resolution: Option<&AiPetResolution>) -> Option<AiPetDisplaySnapshot> {
    match pet_resolution {
        Some(AiPetResolution::Resolved { snapshot, .. }) => Some(snapshot.clone()),
        _ => None,
    }
}

/// pet_resolution_message_text 返回宠物解析分支安全提示
/// 核心职责：
/// - 为无宠物、歧义和未授权场景提供不泄漏隐私的文案
fn pet_resolution_message_text(resolution: &AiPetResolution) -> &'static str {
    match resolution {
        AiPetResolution::NeedsSelection { .. } => "我需要先确认你想问哪只宠物。",
        AiPetResolution::UnauthorizedOrNotFound => "我没有找到你有权限访问的这只宠物。",
        AiPetResolution::NoPetContext => "请先创建或选择一只宠物，我再围绕它的记录继续回答。",
        AiPetResolution::Resolved { .. } => "已确认目标宠物。",
    }
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
