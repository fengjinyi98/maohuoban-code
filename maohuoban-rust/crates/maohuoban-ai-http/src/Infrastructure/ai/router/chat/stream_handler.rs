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
use maohuoban_ai_application::ai::intent::AiIntentGate;
use maohuoban_ai_application::ai::ports::{AiRequestGateLog, AiToolAccessLog};
use maohuoban_ai_application::ai::stream::AiStreamRunContext;
use maohuoban_ai_domain::ai::{
    AiFactPackage, AiGateDecision, AiIntent, AiPetDisplaySnapshot, AiPetResolution, AiStreamEvent,
    AiToolCallStatus,
};
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};
use uuid::Uuid;

use super::super::AiHttpState;
use super::super::auth::current_user_id;
use super::assistant_message_persistence::spawn_assistant_message_persist;
use super::diet_confirmation_candidate_loader::load_diet_confirmation_candidate_package;
use super::diet_fact_loader::load_current_diet_fact_package;
use super::fact_package_merge::merge_fact_packages;
use super::food_inventory_hint_loader::load_food_inventory_hint_package;
use super::gated_stream_response::gated_stream_response;
use super::identity_fact_loader::load_identity_fact_package;
use super::llm_request::build_llm_request;
use super::pet_resolution_stream_response::pet_resolution_stream_response;
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

    let session_id = req.chat_session_id.unwrap_or_else(Uuid::new_v4);
    let message_id = Uuid::new_v4();
    let now = Utc::now();
    let title = build_title(&req.message);
    let gate_decision = AiIntentGate::new().classify(&req.message);

    let pet_resolution =
        resolve_stream_target_pet(&state, &req, actor_user_id, &gate_decision).await;
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

    let initial_events = load_pet_catalog_initial_events(
        &state.session_repository,
        session_id,
        actor_user_id,
        &gate_decision,
        resolved_pet_id,
        req.selected_pet_id,
        pet_resolution.as_ref(),
    )
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

    let (fact_package, initial_events) = load_fact_context_and_initial_events(
        &state,
        session_id,
        actor_user_id,
        target_pet.as_ref(),
        initial_events,
    )
    .await;

    let llm_request = build_llm_request(&req.message, target_pet.as_ref(), fact_package.as_ref());
    let stream = state.stream_pipeline.run_with_context(
        llm_request,
        AiStreamRunContext {
            chat_session_id: session_id,
            message_id,
            title,
            target_pet,
            initial_events,
            fact_package,
        },
    );

    provider_stream_response(
        stream,
        state.session_repository.clone(),
        session_id,
        message_id,
    )
}

/// load_fact_context_and_initial_events 加载事实上下文并拼接初始事件
/// 核心职责：
/// - 依次加载身份事实和当前饮食事实
/// - 合并工具事件，保持 Provider 前的上下文准备集中
async fn load_fact_context_and_initial_events(
    state: &AiHttpState,
    session_id: Uuid,
    actor_user_id: Uuid,
    target_pet: Option<&AiPetDisplaySnapshot>,
    mut initial_events: Vec<AiStreamEvent>,
) -> (Option<AiFactPackage>, Vec<AiStreamEvent>) {
    let (identity_fact_package, identity_events) =
        load_identity_fact_package(state, session_id, actor_user_id, target_pet).await;
    let (diet_fact_package, diet_events) =
        load_current_diet_fact_package(state, session_id, actor_user_id, target_pet).await;
    let (food_inventory_hint_package, food_inventory_hint_events) =
        load_food_inventory_hint_package(state, session_id, actor_user_id, target_pet).await;
    let (diet_confirmation_candidate_package, diet_confirmation_candidate_events) =
        load_diet_confirmation_candidate_package(state, session_id, actor_user_id, target_pet)
            .await;
    initial_events.extend(identity_events);
    initial_events.extend(diet_events);
    initial_events.extend(food_inventory_hint_events);
    initial_events.extend(diet_confirmation_candidate_events);

    (
        merge_fact_packages(
            merge_fact_packages(identity_fact_package, diet_fact_package),
            merge_fact_packages(
                food_inventory_hint_package,
                diet_confirmation_candidate_package,
            ),
        ),
        initial_events,
    )
}

/// resolve_stream_target_pet 解析流式请求目标宠物
/// 核心职责：
/// - 只在 gate 要求加载上下文时调用后端授权宠物解析器
/// - 将解析失败降级为无宠物上下文，保持 SSE 主链路可返回安全响应
async fn resolve_stream_target_pet(
    state: &AiHttpState,
    req: &ChatStreamRequest,
    actor_user_id: Uuid,
    gate_decision: &AiGateDecision,
) -> Option<AiPetResolution> {
    if gate_decision.context_loaded {
        state
            .pet_resolver
            .resolve(&req.message, req.selected_pet_id, actor_user_id)
            .await
            .ok()
    } else {
        None
    }
}

/// load_pet_catalog_initial_events 加载宠物候选工具初始事件
/// 核心职责：
/// - 只在需要上下文的请求中记录宠物候选工具审计
/// - 返回可在 message_started 后输出的 tool_call 事件
async fn load_pet_catalog_initial_events(
    session_repo: &std::sync::Arc<dyn maohuoban_ai_application::ai::ports::AiSessionRepository>,
    session_id: Uuid,
    actor_user_id: Uuid,
    gate_decision: &AiGateDecision,
    resolved_pet_id: Option<Uuid>,
    selected_pet_id: Option<Uuid>,
    pet_resolution: Option<&AiPetResolution>,
) -> Vec<AiStreamEvent> {
    if gate_decision.context_loaded {
        insert_pet_catalog_tool_log(
            session_repo,
            session_id,
            actor_user_id,
            resolved_pet_id,
            selected_pet_id,
            pet_resolution,
        )
        .await
    } else {
        Vec::new()
    }
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

/// resolved_pet_snapshot 提取已解析宠物快照
/// 核心职责：
/// - 只在 AiPetResolution::Resolved 时返回后端宠物展示快照
fn resolved_pet_snapshot(pet_resolution: Option<&AiPetResolution>) -> Option<AiPetDisplaySnapshot> {
    match pet_resolution {
        Some(AiPetResolution::Resolved { snapshot, .. }) => Some(snapshot.clone()),
        _ => None,
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
