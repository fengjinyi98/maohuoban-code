use chrono::Utc;
use maohuoban_ai_application::ai::intent::AiIntentGate;
use maohuoban_ai_application::ai::ports::{
    AiRequestGateLog, AiSessionRepository, AiToolAccessLog, IngressTxInput,
};
use maohuoban_ai_domain::ai::{
    AgentTurnId, AiChatSession, AiChatSessionStatus, AiGateDecision, AiIntent, AiMessage,
    AiMessageRole, AiMessageStatus, AiPetDisplaySnapshot, AiPetResolution, AiSessionTurn,
    AiSessionTurnStatus, AiStreamEvent,
};
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};
use std::sync::Arc;
use uuid::Uuid;

use super::super::AiHttpState;
use super::composition::request::ChatStreamRequest;
use super::composition::title::build_title;
use super::runtime_stream_helpers::safe_execution_trace_completed_for_tool;

/// ChatTurnContext 聊天轮次准备结果
/// 核心职责：
/// - 统一承载流式与非流式入口共享的轮次上下文
/// - 固定用户消息和助手消息使用不同 ID 的持久化合同
pub(super) struct ChatTurnContext {
    pub(super) session_id: Uuid,
    pub(super) turn_id: AgentTurnId,
    pub(super) user_message_id: Uuid,
    pub(super) assistant_message_id: Uuid,
    pub(super) title: String,
    pub(super) gate_decision: AiGateDecision,
    pub(super) pet_resolution: Option<AiPetResolution>,
    pub(super) resolved_pet_id: Option<Uuid>,
    pub(super) target_pet: Option<AiPetDisplaySnapshot>,
    pub(super) effective_selected_pet_id: Option<Uuid>,
}

/// prepare_chat_turn_context 准备聊天轮次上下文
/// 核心职责：
/// - 创建会话 ID、用户消息 ID 和助手消息 ID
/// - 完成意图闸门、有效宠物 ID 恢复和授权宠物解析
pub(super) async fn prepare_chat_turn_context(
    state: &AiHttpState,
    req: &ChatStreamRequest,
    actor_user_id: Uuid,
) -> ChatTurnContext {
    let gate_decision = AiIntentGate::new().classify(&req.message);
    let effective_selected_pet_id = effective_selected_pet_id(state, req, actor_user_id).await;
    let pet_resolution = resolve_target_pet(
        state,
        req,
        actor_user_id,
        effective_selected_pet_id,
        &gate_decision,
    )
    .await;
    let resolved_pet_id = pet_resolution
        .as_ref()
        .and_then(AiPetResolution::resolved_pet_id);
    let target_pet = resolved_pet_snapshot(pet_resolution.as_ref());

    ChatTurnContext {
        session_id: req.chat_session_id.unwrap_or_else(Uuid::new_v4),
        turn_id: AgentTurnId::new(),
        user_message_id: Uuid::new_v4(),
        assistant_message_id: Uuid::new_v4(),
        title: build_title(&req.message),
        gate_decision,
        pet_resolution,
        resolved_pet_id,
        target_pet,
        effective_selected_pet_id,
    }
}

/// persist_prepared_chat_turn 在单个事务内持久化已准备的聊天轮次
/// 核心职责：
/// - 在 Ingress Tx 中写入 session、user message、turn 账本行和 gate 审计日志
/// - 消除多次独立仓储调用导致的中间态不一致风险
pub(super) async fn persist_prepared_chat_turn(
    state: &AiHttpState,
    req: &ChatStreamRequest,
    actor_user_id: Uuid,
    context: &ChatTurnContext,
) {
    let now = Utc::now();
    let primary_pet_id = context
        .resolved_pet_id
        .or(context.effective_selected_pet_id);

    let session = AiChatSession {
        id: context.session_id,
        actor_user_id,
        primary_pet_id,
        surface: req.surface,
        source_hint_id: req.source_hint_id,
        source_task_id: req.confirmation_task_id,
        title: context.title.clone(),
        is_pinned: false,
        pet_display_snapshot: context.target_pet.clone(),
        status: AiChatSessionStatus::Active,
        created_at: now,
        updated_at: now,
    };

    let user_message = AiMessage {
        id: context.user_message_id,
        session_id: context.session_id,
        turn_id: None,
        role: AiMessageRole::User,
        content: req.message.clone(),
        status: AiMessageStatus::Completed,
        citations: vec![],
        model: None,
        provider: None,
        finish_reason: None,
        usage_input_tokens: None,
        usage_output_tokens: None,
        verification: None,
        created_at: now,
    };

    let turn = AiSessionTurn {
        id: context.turn_id.as_uuid(),
        session_id: context.session_id,
        actor_user_id,
        user_message_id: context.user_message_id,
        assistant_message_id: None,
        intent: intent_code(context.gate_decision.intent).to_owned(),
        gate_decision: gate_decision_code(&context.gate_decision).to_owned(),
        resolved_pet_id: context.resolved_pet_id,
        engine_mode: "self_hosted".to_owned(),
        surface: req.surface,
        status: AiSessionTurnStatus::Running,
        finish_reason: None,
        error_code: None,
        retryable: None,
        started_at: now,
        finished_at: None,
    };

    let gate_log = AiRequestGateLog {
        session_id: Some(context.session_id),
        actor_user_id,
        intent: intent_code(context.gate_decision.intent).to_owned(),
        gate_decision: gate_decision_code(&context.gate_decision).to_owned(),
        context_loaded: context.gate_decision.context_loaded,
        request_hash: request_hash(&req.message),
        resolved_pet_id: context.resolved_pet_id,
        selected_pet_id: context.effective_selected_pet_id,
        risk_signal: context.gate_decision.risk_signal.clone(),
        estimated_input_tokens: i32::try_from(req.message.chars().count()).unwrap_or(i32::MAX),
    };

    let _ = state
        .chat_turn_transaction
        .persist_ingress_tx(&IngressTxInput {
            session: &session,
            user_message: &user_message,
            turn: &turn,
            gate_log: &gate_log,
        })
        .await;
}

/// load_pet_catalog_initial_events 加载宠物候选工具初始事件
/// 核心职责：
/// - 只在需要上下文的请求中记录宠物候选工具审计
/// - 返回可在 message_started 后输出的安全执行态事件
pub(super) async fn load_pet_catalog_initial_events(
    session_repo: &Arc<dyn AiSessionRepository>,
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

/// effective_selected_pet_id 解析本轮有效宠物 ID
/// 核心职责：
/// - 优先使用请求显式 selected_pet_id
/// - 历史会话继续对话时从归属当前用户的 session 恢复 primary_pet_id
async fn effective_selected_pet_id(
    state: &AiHttpState,
    req: &ChatStreamRequest,
    actor_user_id: Uuid,
) -> Option<Uuid> {
    if req.selected_pet_id.is_some() {
        return req.selected_pet_id;
    }

    let session_id = req.chat_session_id?;
    let session = state
        .session_repository
        .get_session(session_id)
        .await
        .ok()??;
    if session.actor_user_id == actor_user_id {
        session.primary_pet_id
    } else {
        None
    }
}

/// resolve_target_pet 解析请求目标宠物
/// 核心职责：
/// - 只在 gate 要求加载上下文时调用后端授权宠物解析器
/// - 将解析失败降级为无宠物上下文，保持主链路可返回安全响应
async fn resolve_target_pet(
    state: &AiHttpState,
    req: &ChatStreamRequest,
    actor_user_id: Uuid,
    selected_pet_id: Option<Uuid>,
    gate_decision: &AiGateDecision,
) -> Option<AiPetResolution> {
    if gate_decision.context_loaded {
        state
            .pet_resolver
            .resolve(&req.message, selected_pet_id, actor_user_id)
            .await
            .ok()
    } else {
        None
    }
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

/// insert_pet_catalog_tool_log 写入授权宠物候选工具审计
/// 核心职责：
/// - 记录 list_authorized_pet_candidates 工具读取
/// - 为解析成功的请求返回不含内部工具名的初始执行态
async fn insert_pet_catalog_tool_log(
    session_repo: &Arc<dyn AiSessionRepository>,
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
        vec![safe_execution_trace_completed_for_tool(
            "list_authorized_pet_candidates",
            "宠物",
            0,
        )]
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
    if !gate_decision.enters_workbench() {
        "blocked"
    } else if gate_decision.context_loaded {
        "load_context"
    } else {
        "enter_workbench"
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
