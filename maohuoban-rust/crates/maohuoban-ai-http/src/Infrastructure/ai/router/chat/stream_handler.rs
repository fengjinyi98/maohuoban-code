use axum::{
    Json,
    extract::State,
    http::HeaderMap,
    response::{
        IntoResponse, Response,
        sse::{Event, KeepAlive, Sse},
    },
};
use futures_util::StreamExt;
use maohuoban_ai_application::ai::conversation_history::RecentConversationLoader;
use maohuoban_ai_application::ai::runtime::{AgentRuntimeLoopEngine, AgentSession};
use maohuoban_ai_application::ai::session_summary::SessionSummaryCompressor;
use maohuoban_ai_application::ai::stream::AiStreamRunContext;
use maohuoban_ai_application::ai::tools::{AiToolContext, ToolRegistry};
use maohuoban_ai_application::ai::turn_context::ContextBudgetPolicy;
use maohuoban_ai_domain::ai::{
    AgentId, AgentSessionWorkbench, AiFactPackage, AiGateDecision, AiPetDisplaySnapshot,
    AiStreamEvent,
};
use std::sync::Arc;
use uuid::Uuid;

use super::super::AiHttpState;
use super::super::auth::current_user_id;
use super::super::diagnostics::{
    record_chat_gate_decided, record_chat_provider_error, record_chat_provider_started,
    record_chat_stream_event_emitted, record_chat_stream_request_received,
};
use super::assistant_message_persistence::{
    AssistantMessagePersistRequest, persist_assistant_message,
};
use super::diet_confirmation_candidate_loader::load_diet_confirmation_candidate_package;
use super::diet_fact_loader::load_current_diet_fact_package;
use super::fact_package_merge::merge_fact_packages;
use super::food_inventory_hint_loader::load_food_inventory_hint_package;
use super::gated_stream_response::gated_stream_response;
use super::identity_fact_loader::load_identity_fact_package;
use super::pet_resolution_stream_response::pet_resolution_stream_response;
use super::request::ChatStreamRequest;
use super::runtime_stream::{
    AgentEventSseProjector, ai_error_to_sse_event, sanitize_legacy_tool_call_event,
};
use super::runtime_tools::build_runtime_tool_registry;
use super::turn_preparation::{
    load_pet_catalog_initial_events, persist_prepared_chat_turn, prepare_chat_turn_context,
};
use super::workbench_builder::build_agent_session_workbench;
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

    let context = prepare_chat_turn_context(&state, &req, actor_user_id).await;
    record_stream_request_received(&req, actor_user_id, context.session_id);
    record_stream_gate_decided(
        context.session_id,
        context.effective_selected_pet_id,
        context.resolved_pet_id,
        &context.gate_decision,
    );
    persist_prepared_chat_turn(&state, &req, actor_user_id, &context).await;

    let initial_events = load_pet_catalog_initial_events(
        &state.session_repository,
        context.session_id,
        actor_user_id,
        &context.gate_decision,
        context.resolved_pet_id,
        context.effective_selected_pet_id,
        context.pet_resolution.as_ref(),
    )
    .await;

    if !context.gate_decision.enters_workbench() {
        return gated_stream_response(
            state.session_repository.clone(),
            context.session_id,
            context.assistant_message_id,
            context.title,
            &context.gate_decision,
        );
    }

    if let Some(resolution) = context
        .pet_resolution
        .as_ref()
        .filter(|resolution| !resolution.is_resolved())
    {
        return pet_resolution_stream_response(
            state.session_repository.clone(),
            context.session_id,
            context.assistant_message_id,
            context.title,
            resolution.clone(),
        );
    }

    provider_response_for_context(
        &state,
        &req,
        ProviderResponseInput {
            session_id: context.session_id,
            message_id: context.assistant_message_id,
            title: context.title,
            actor_user_id,
            target_pet: context.target_pet,
            initial_events,
            user_message_id: context.user_message_id,
        },
    )
    .await
}

/// ProviderResponseInput Provider 响应构建输入
/// 核心职责：
/// - 承载 stream 主链路进入 Provider 分支所需上下文
/// - 控制 helper 参数数量并保持所有权边界清晰
struct ProviderResponseInput {
    session_id: Uuid,
    message_id: Uuid,
    title: String,
    actor_user_id: Uuid,
    target_pet: Option<AiPetDisplaySnapshot>,
    initial_events: Vec<AiStreamEvent>,
    user_message_id: Uuid,
}

/// provider_response_for_context 构建 Provider SSE 响应
/// 核心职责：
/// - 加载事实包并记录 Provider 分支入口
/// - 将 LLM 请求交给 stream pipeline 生成稳定 SSE
async fn provider_response_for_context(
    state: &AiHttpState,
    req: &ChatStreamRequest,
    input: ProviderResponseInput,
) -> Response {
    let (fact_package, initial_events) = load_fact_context_and_initial_events(
        state,
        input.session_id,
        input.actor_user_id,
        input.target_pet.as_ref(),
        input.initial_events,
    )
    .await;

    record_provider_context_started(
        input.session_id,
        input.message_id,
        input.target_pet.as_ref(),
        &initial_events,
        fact_package.as_ref(),
    );

    let stream_context = AiStreamRunContext {
        chat_session_id: input.session_id,
        message_id: input.message_id,
        title: input.title,
        target_pet: input.target_pet.clone(),
        initial_events,
        fact_package: fact_package.clone(),
    };
    let (recent_conversation, session_summary) = load_history_and_summary(
        state,
        input.actor_user_id,
        input.session_id,
        input.user_message_id,
    )
    .await;

    let workbench = build_agent_session_workbench(
        req.surface,
        input.target_pet.as_ref(),
        session_summary,
        Vec::new(),
        recent_conversation,
    );
    let stream = runtime_provider_stream(
        state,
        req,
        RuntimeProviderStreamInput {
            session_id: input.session_id,
            message_id: input.message_id,
            actor_user_id: input.actor_user_id,
            target_pet: input.target_pet,
            fact_package,
            context: stream_context,
            workbench,
        },
    );

    provider_stream_response(
        stream,
        state.session_repository.clone(),
        input.session_id,
        input.message_id,
    )
}

/// RuntimeProviderStreamInput Runtime SSE 构建输入
/// 核心职责：
/// - 汇总 Agent Runtime 运行所需上下文
/// - 控制 runtime_provider_stream 参数数量
struct RuntimeProviderStreamInput {
    session_id: Uuid,
    message_id: Uuid,
    actor_user_id: Uuid,
    target_pet: Option<AiPetDisplaySnapshot>,
    fact_package: Option<AiFactPackage>,
    context: AiStreamRunContext,
    workbench: AgentSessionWorkbench,
}

/// runtime_provider_stream 通过自有 Agent Runtime 构建 SSE 流
/// 核心职责：
/// - 使用 AgentSession 驱动模型、工具和二次模型调用
/// - 将 Runtime 事件映射回现有 AiStreamEvent 协议
fn runtime_provider_stream(
    state: &AiHttpState,
    req: &ChatStreamRequest,
    input: RuntimeProviderStreamInput,
) -> futures_util::stream::BoxStream<'static, Result<AiStreamEvent, maohuoban_ai_domain::ai::AiError>>
{
    let provider = state.llm_provider.clone();
    let registry = Arc::new(match input.target_pet.as_ref() {
        Some(target_pet) => build_runtime_tool_registry(state, input.session_id, target_pet),
        None => ToolRegistry::new(),
    });
    let tool_context = AiToolContext {
        actor_user_id: input.actor_user_id,
        authorized_pet_id: input
            .target_pet
            .as_ref()
            .map_or_else(Uuid::nil, |pet| pet.pet_id),
    };
    let engine =
        AgentRuntimeLoopEngine::new(provider, registry, tool_context, input.fact_package.clone());
    let session = AgentSession::new(
        input.session_id,
        AgentId::main_pet_care_agent(),
        req.surface,
        engine,
    );
    let user_message = req.message.clone();
    let message_id = input.message_id;
    let fact_package = input.fact_package;
    let context = input.context;
    let workbench = input.workbench;

    async_stream::stream! {
        let AiStreamRunContext {
            chat_session_id,
            message_id: started_message_id,
            title,
            target_pet,
            initial_events,
            ..
        } = context;
        let activity_pet_name = target_pet
            .as_ref()
            .map_or_else(|| "宠物".to_owned(), |pet| pet.pet_name.clone());

        yield Ok(AiStreamEvent::MessageStarted {
            chat_session_id,
            message_id: started_message_id,
            target_pet,
            title,
        });

        for event in initial_events {
            yield Ok(sanitize_legacy_tool_call_event(event, &activity_pet_name));
        }

        let mut projector = AgentEventSseProjector::new(message_id, fact_package, &activity_pet_name);
        let mut agent_stream = session.into_prompt_stream_with_workbench(user_message, workbench);
        while let Some(result) = agent_stream.next().await {
            match result {
                Ok(agent_event) => {
                    for event in projector.project(agent_event) {
                        yield Ok(event);
                    }
                }
                Err(error) => {
                    yield Ok(ai_error_to_sse_event(&error));
                    break;
                }
            }
        }
    }
    .boxed()
}

/// record_stream_request_received 记录 stream 请求入口观测
/// 核心职责：
/// - 从请求体提取脱敏诊断字段
/// - 保持主 handler 聚焦链路编排
fn record_stream_request_received(req: &ChatStreamRequest, actor_user_id: Uuid, session_id: Uuid) {
    record_chat_stream_request_received(
        actor_user_id,
        session_id,
        req.selected_pet_id,
        req.surface,
        &req.message,
    );
}

/// record_stream_gate_decided 记录 stream gate 决策观测
/// 核心职责：
/// - 关联会话、选择宠物和解析宠物
/// - 保持 gate 诊断字段集中构造
fn record_stream_gate_decided(
    session_id: Uuid,
    selected_pet_id: Option<Uuid>,
    resolved_pet_id: Option<Uuid>,
    gate_decision: &AiGateDecision,
) {
    record_chat_gate_decided(session_id, selected_pet_id, resolved_pet_id, gate_decision);
}

/// record_provider_context_started 记录 Provider 分支上下文状态
/// 核心职责：
/// - 在进入 Provider 前记录事实包和初始事件状态
/// - 为 provider 错误和 SSE 输出提供前置证据
fn record_provider_context_started(
    session_id: Uuid,
    message_id: Uuid,
    target_pet: Option<&AiPetDisplaySnapshot>,
    initial_events: &[AiStreamEvent],
    fact_package: Option<&AiFactPackage>,
) {
    record_chat_provider_started(
        session_id,
        message_id,
        target_pet.is_some(),
        initial_events.len(),
        fact_package.is_some(),
    );
}

/// load_fact_context_and_initial_events 加载事实上下文并拼接初始事件
/// 核心职责：
/// - 依次加载身份事实和当前饮食事实
/// - 合并工具事件，保持 Provider 前的上下文准备集中
pub(super) async fn load_fact_context_and_initial_events(
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
    let sse_stream = stream.then(move |result| {
        let session_repo = session_repo.clone();
        async move {
            let event = match result {
                Ok(e) => e,
                Err(err) => AiStreamEvent::Error {
                    code: err.stable_code().to_owned(),
                    message: err.user_visible_message().to_owned(),
                    retryable: err.is_retryable(),
                    blocked_reason: None,
                    safe_fallback_text: Some("暂时无法获取回答，请稍后重试。".to_owned()),
                },
            };

            if let AiStreamEvent::Error {
                code,
                retryable,
                safe_fallback_text,
                ..
            } = &event
            {
                record_chat_provider_error(
                    session_id,
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

/// load_history_and_summary 加载历史和会话摘要
/// 核心职责：
/// - 加载同会话历史（含归属校验和预算裁剪）
/// - 尝试压缩历史并生成摘要
/// - 加载已有有效摘要
/// - 任何步骤失败不阻塞主链路
async fn load_history_and_summary(
    state: &AiHttpState,
    actor_user_id: Uuid,
    session_id: Uuid,
    exclude_message_id: Uuid,
) -> (
    maohuoban_ai_domain::ai::RecentConversationPack,
    Option<String>,
) {
    let session_repo = &state.session_repository;
    let summary_repo = &state.session_summary_repository;
    let loader = RecentConversationLoader::new(session_repo.clone(), summary_repo.clone());

    let pack = match loader
        .load_recent_conversation(
            actor_user_id,
            session_id,
            exclude_message_id,
            1_000_000,
            200_000,
        )
        .await
    {
        Ok(pack) => ContextBudgetPolicy::default_for_deepseek_1m().trim(&pack),
        Err(_) => {
            return (
                maohuoban_ai_domain::ai::RecentConversationPack::empty(),
                None,
            );
        }
    };

    // 尝试压缩（历史超过阈值时生成摘要）
    let compressor = SessionSummaryCompressor::new(
        state.llm_provider.clone(),
        state.session_summary_repository.clone(),
    );

    // 加载原始消息用于压缩评估
    let Ok(raw_messages) = session_repo.list_messages_by_session(session_id).await else {
        return (pack, None);
    };

    if let Ok(Some(compressed)) = compressor
        .try_compress(
            session_id,
            actor_user_id,
            &raw_messages,
            3,
            Some(exclude_message_id),
        )
        .await
    {
        return (
            compressed.retained_tail,
            Some(compressed.summary.to_context_summary()),
        );
    }

    // 未触发压缩，加载已有摘要
    let summary_text = match compressor.load_active_summary(session_id).await {
        Ok(Some(s)) => Some(s.to_context_summary()),
        _ => None,
    };

    (pack, summary_text)
}
