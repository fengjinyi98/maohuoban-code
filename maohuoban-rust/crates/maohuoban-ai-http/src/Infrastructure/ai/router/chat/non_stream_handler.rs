use axum::{Json, extract::State, http::HeaderMap, response::Response};
use chrono::Utc;
use maohuoban_ai_application::ai::citations::citations_for_answer;
use maohuoban_ai_application::ai::conversation_history::RecentConversationLoader;
use maohuoban_ai_application::ai::runtime::{
    AgentRuntimeEngineFactory, AgentRuntimeEngineInput, AgentSession,
};
use maohuoban_ai_application::ai::session_summary::SessionSummaryCompressor;
use maohuoban_ai_application::ai::stream::AiCompleteResult;
use maohuoban_ai_application::ai::tools::{AiToolContext, ToolRegistry};
use maohuoban_ai_application::ai::turn_context::ContextBudgetPolicy;
use maohuoban_ai_application::ai::verifier::AiAnswerVerifier;
use maohuoban_ai_domain::ai::{
    AgentEvent, AgentId, AiAnswerVerification, AiCitation, AiError, AiFactPackage, AiMessage,
    AiMessageRole, AiMessageStatus, AiPetDisplaySnapshot, LlmFinishReason, LlmUsage,
};
use serde::Serialize;
use std::sync::Arc;
use uuid::Uuid;

use super::super::AiHttpState;
use super::super::auth::current_user_id;
use super::gated_stream_response::gated_message_text;
use super::pet_resolution_stream_response::pet_resolution_message_text;
use super::request::ChatStreamRequest;
use super::runtime_tools::build_runtime_tool_registry;
use super::stream_handler::load_fact_context_and_initial_events;
use super::turn_preparation::{
    ChatTurnContext, load_pet_catalog_initial_events, persist_prepared_chat_turn,
    prepare_chat_turn_context,
};
use super::workbench_builder::build_agent_session_workbench;
use crate::ai::response::{ai_error_response, ok_response, unauthorized_response};

/// handle_chat 非流式聊天 handler
/// 核心职责：
/// - 校验登录态并从 token 注入 actor
/// - 复用流式链路的宠物解析、事实包、回答校验和消息持久化
pub async fn handle_chat(
    State(state): State<AiHttpState>,
    headers: HeaderMap,
    Json(req): Json<ChatStreamRequest>,
) -> Response {
    let Ok(actor_user_id) = current_user_id(&state.auth, &headers).await else {
        return unauthorized_response();
    };

    let context = prepare_chat_turn_context(&state, &req, actor_user_id).await;
    persist_prepared_chat_turn(&state, &req, actor_user_id, &context).await;

    let _ = load_pet_catalog_initial_events(
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
        return persist_and_respond_boundary_message(
            &state.session_repository,
            context.assistant_message_id,
            context.session_id,
            context.title,
            context.target_pet,
            gated_message_text(&context.gate_decision).to_owned(),
            "gate_skipped_main_agent".to_owned(),
        )
        .await;
    }

    if let Some(resolution) = context
        .pet_resolution
        .as_ref()
        .filter(|resolution| !resolution.is_resolved())
    {
        return persist_and_respond_boundary_message(
            &state.session_repository,
            context.assistant_message_id,
            context.session_id,
            context.title,
            context.target_pet,
            pet_resolution_message_text(resolution).to_owned(),
            "pet_resolution_skipped_main_agent".to_owned(),
        )
        .await;
    }

    let (fact_package, _initial_events) = load_fact_context_and_initial_events(
        &state,
        context.session_id,
        actor_user_id,
        context.target_pet.as_ref(),
        Vec::new(),
    )
    .await;

    let complete_result = complete_with_runtime(
        &state,
        &req,
        actor_user_id,
        &context,
        context.target_pet.clone(),
        fact_package,
    )
    .await;
    let complete = match complete_result {
        Ok(result) => result,
        Err(error) => return ai_error_response(&error),
    };

    persist_assistant_message(
        &state.session_repository,
        context.assistant_message_id,
        context.session_id,
        &complete,
    )
    .await;

    ok_response(
        "ai.chat_completed",
        "AI 回答已完成",
        ChatCompleteResponse {
            chat_session_id: context.session_id,
            message_id: context.assistant_message_id,
            title: context.title,
            target_pet: context.target_pet,
            final_text: complete.final_text,
            citations: complete.citations,
            usage: complete.usage,
            finish_reason: complete.finish_reason,
            verification: complete.verification,
        },
    )
}

/// complete_with_runtime 使用自有 Agent Runtime 完成非流式回答
/// 核心职责：
/// - 通过 AgentSession 驱动模型、Tool Gateway 和二次模型调用
/// - 将 Runtime 事件聚合为非流式完成结果
async fn complete_with_runtime(
    state: &AiHttpState,
    req: &ChatStreamRequest,
    actor_user_id: Uuid,
    context: &ChatTurnContext,
    target_pet: Option<AiPetDisplaySnapshot>,
    fact_package: Option<AiFactPackage>,
) -> Result<AiCompleteResult, AiError> {
    let registry = Arc::new(match target_pet.as_ref() {
        Some(target_pet) => build_runtime_tool_registry(state, context.session_id, target_pet),
        None => ToolRegistry::new(),
    });
    let tool_context = AiToolContext {
        actor_user_id,
        authorized_pet_id: target_pet.as_ref().map_or_else(Uuid::nil, |pet| pet.pet_id),
    };
    let engine =
        AgentRuntimeEngineFactory::new(state.runtime_engine_mode).build(AgentRuntimeEngineInput {
            provider: state.llm_provider.clone(),
            registry,
            tool_context,
            fact_package: fact_package.clone(),
        });
    let mut session = AgentSession::new(
        context.session_id,
        AgentId::main_pet_care_agent(),
        req.surface,
        engine,
    );
    let (recent_conversation, session_summary) = load_history_and_summary_non_stream(
        state,
        actor_user_id,
        context.session_id,
        context.user_message_id,
    )
    .await;

    let workbench = build_agent_session_workbench(
        req.surface,
        target_pet.as_ref(),
        session_summary,
        Vec::new(),
        recent_conversation,
    );
    let events = session
        .prompt_with_workbench(req.message.clone(), workbench)
        .await?;
    complete_from_runtime_events(events, fact_package)
}

/// complete_from_runtime_events 聚合 Runtime 事件
/// 核心职责：
/// - 提取最终文本、用量和 Provider 元数据
/// - 复用回答校验器生成非流式响应数据
fn complete_from_runtime_events(
    events: Vec<AgentEvent>,
    fact_package: Option<AiFactPackage>,
) -> Result<AiCompleteResult, AiError> {
    let package = fact_package.unwrap_or_else(AiFactPackage::empty);
    let mut usage = LlmUsage::default();
    let mut finish_reason = LlmFinishReason::Stop;
    let mut provider = "runtime".to_owned();
    let mut model = "primary".to_owned();
    let mut completed_text = None;

    for event in events {
        match event {
            AgentEvent::ModelCallFinished {
                finish_reason: event_finish_reason,
                usage: event_usage,
                provider: event_provider,
                model: event_model,
                ..
            } => {
                usage = event_usage;
                finish_reason = event_finish_reason;
                provider = event_provider;
                model = event_model;
            }
            AgentEvent::TurnFinished { final_text, .. } => {
                completed_text = Some(final_text);
            }
            AgentEvent::TurnFailed { error_code, .. } => {
                return Err(AiError::Infrastructure(error_code));
            }
            _ => {}
        }
    }

    let final_text = completed_text
        .ok_or_else(|| AiError::Infrastructure("runtime turn did not finish".to_owned()))?;
    let verification = AiAnswerVerifier::new().verify(&final_text, &package);

    if verification.is_blocked() {
        let safe_text = verification
            .safe_fallback_text
            .clone()
            .unwrap_or_else(|| "回答内容未通过安全校验。".to_owned());
        let citations = citations_for_answer(&safe_text, &package);
        return Ok(AiCompleteResult {
            final_text: safe_text,
            usage,
            finish_reason: LlmFinishReason::ContentFilter,
            provider,
            model,
            citations,
            verification,
        });
    }

    let citations = citations_for_answer(&final_text, &package);
    Ok(AiCompleteResult {
        final_text,
        usage,
        finish_reason,
        provider,
        model,
        citations,
        verification,
    })
}

/// ChatCompleteResponse 非流式聊天完成响应
/// 核心职责：
/// - 对齐流式完成后的聚合结果
/// - 返回前端渲染和调试所需的最小字段
#[derive(Serialize)]
struct ChatCompleteResponse {
    chat_session_id: Uuid,
    message_id: Uuid,
    title: String,
    target_pet: Option<AiPetDisplaySnapshot>,
    final_text: String,
    citations: Vec<AiCitation>,
    usage: LlmUsage,
    finish_reason: LlmFinishReason,
    verification: AiAnswerVerification,
}

/// persist_assistant_message 持久化非流式助手消息
/// 核心职责：
/// - 保存最终回答、Provider 元信息和回答校验结果
/// - 保持非流式与流式历史读取路径一致
async fn persist_assistant_message(
    repo: &std::sync::Arc<dyn maohuoban_ai_application::ai::ports::AiSessionRepository>,
    message_id: Uuid,
    session_id: Uuid,
    complete: &maohuoban_ai_application::ai::stream::AiCompleteResult,
) {
    persist_assistant_message_from_parts(
        repo,
        AssistantMessageRecord {
            message_id,
            session_id,
            final_text: complete.final_text.clone(),
            citations: complete.citations.clone(),
            usage: complete.usage,
            finish_reason: format!("{:?}", complete.finish_reason),
            provider: Some(complete.provider.clone()),
            model: Some(complete.model.clone()),
            verification: Some(complete.verification.clone()),
        },
    )
    .await;
}

/// persist_and_respond_boundary_message 返回非 Provider 分支聚合结果
/// 核心职责：
/// - 持久化 gate / 宠物解析边界消息
/// - 返回与 Provider 完成一致的响应形状
async fn persist_and_respond_boundary_message(
    repo: &std::sync::Arc<dyn maohuoban_ai_application::ai::ports::AiSessionRepository>,
    message_id: Uuid,
    session_id: Uuid,
    title: String,
    target_pet: Option<AiPetDisplaySnapshot>,
    final_text: String,
    finish_reason: String,
) -> Response {
    let usage = LlmUsage::default();
    let verification = AiAnswerVerification::passed();
    persist_assistant_message_from_parts(
        repo,
        AssistantMessageRecord {
            message_id,
            session_id,
            final_text: final_text.clone(),
            citations: Vec::new(),
            usage,
            finish_reason,
            provider: None,
            model: None,
            verification: Some(verification.clone()),
        },
    )
    .await;

    ok_response(
        "ai.chat_completed",
        "AI 回答已完成",
        ChatCompleteResponse {
            chat_session_id: session_id,
            message_id,
            title,
            target_pet,
            final_text,
            citations: Vec::new(),
            usage,
            finish_reason: LlmFinishReason::Stop,
            verification,
        },
    )
}

/// AssistantMessageRecord 助手消息持久化输入
/// 核心职责：
/// - 承载助手最终消息字段
/// - 降低持久化 helper 参数复杂度
struct AssistantMessageRecord {
    message_id: Uuid,
    session_id: Uuid,
    final_text: String,
    citations: Vec<AiCitation>,
    usage: LlmUsage,
    finish_reason: String,
    provider: Option<String>,
    model: Option<String>,
    verification: Option<AiAnswerVerification>,
}

/// persist_assistant_message_from_parts 持久化助手消息字段
/// 核心职责：
/// - 统一 Provider 分支和边界分支的消息写入
/// - 保留完成原因、Provider 元信息和校验结果
async fn persist_assistant_message_from_parts(
    repo: &std::sync::Arc<dyn maohuoban_ai_application::ai::ports::AiSessionRepository>,
    record: AssistantMessageRecord,
) {
    let citation_ids = record
        .citations
        .iter()
        .map(|citation| citation.source_id)
        .collect::<Vec<_>>();
    let assistant_message = AiMessage {
        id: record.message_id,
        session_id: record.session_id,
        role: AiMessageRole::Assistant,
        content: record.final_text,
        status: AiMessageStatus::Completed,
        citations: citation_ids,
        model: record.model,
        provider: record.provider,
        finish_reason: Some(record.finish_reason),
        usage_input_tokens: Some(record.usage.input_tokens),
        usage_output_tokens: Some(record.usage.output_tokens),
        verification: record.verification,
        created_at: Utc::now(),
    };
    let _ = repo.insert_message(&assistant_message).await;
    let _ = repo
        .insert_message_citations(record.message_id, record.session_id, &record.citations)
        .await;
}

/// load_history_and_summary_non_stream 加载历史和会话摘要
/// 核心职责：
/// - 加载同会话历史（含归属校验和预算裁剪）
/// - 尝试压缩历史并生成摘要
/// - 加载已有有效摘要
/// - 任何步骤失败不阻塞主链路
async fn load_history_and_summary_non_stream(
    state: &super::super::AiHttpState,
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

    let pack = if let Ok(pack) = loader
        .load_recent_conversation(
            actor_user_id,
            session_id,
            exclude_message_id,
            1_000_000,
            200_000,
        )
        .await
    {
        ContextBudgetPolicy::default_for_deepseek_1m().trim(&pack)
    } else {
        return (
            maohuoban_ai_domain::ai::RecentConversationPack::empty(),
            None,
        );
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
