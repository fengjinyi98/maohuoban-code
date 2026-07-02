//! complete 非流式 Runtime 完成逻辑
//! 核心职责：
//! - 通过 AgentSession 驱动模型、Tool Gateway 和二次模型调用
//! - 将 Runtime 事件聚合为非流式完成结果

use std::collections::HashMap;
use std::sync::Arc;

use maohuoban_ai_application::ai::runtime::{
    AgentRuntimeEngineFactory, AgentRuntimeEngineInput, AgentSession,
};
use maohuoban_ai_application::ai::stream::AiCompleteResult;
use maohuoban_ai_application::ai::tools::{AiToolContext, ToolGatewayExecutionContext};
use maohuoban_ai_application::ai::verifier::{AiAnswerVerificationContext, AiAnswerVerifier};
use maohuoban_ai_domain::ai::{
    AgentEvent, AgentId, AgentToolStatus, AgentTurnStatus, AiError, AiFactPackage, LlmFinishReason,
    LlmUsage,
};
use uuid::Uuid;

use super::super::super::AiHttpState;
use super::super::composition::request::ChatStreamRequest;
use super::super::composition::workbench_builder::{
    build_agent_session_workbench, load_memory_entries_for_workbench,
};
use super::super::content_block_projector::project_pet_profile_content_blocks;
use super::super::runtime_tool_gateway_observer::RuntimeToolGatewayObserver;
use super::super::runtime_tools::{
    build_public_runtime_tool_registry, build_runtime_tool_registry,
};
use super::super::turn_preparation::ChatTurnContext;
use super::history_loader::load_history_and_summary_non_stream;
use crate::ai::router::diagnostics::{
    record_chat_runtime_engine_selected, record_chat_workbench_built,
};
use maohuoban_ai_domain::ai::AiPetDisplaySnapshot;

/// complete_with_runtime 使用自有 Agent Runtime 完成非流式回答
pub(super) async fn complete_with_runtime(
    state: &AiHttpState,
    req: &ChatStreamRequest,
    actor_user_id: Uuid,
    context: &ChatTurnContext,
    target_pet: Option<AiPetDisplaySnapshot>,
    fact_package: Option<AiFactPackage>,
) -> Result<AiCompleteResult, AiError> {
    let (recent_conversation, session_summary) = load_history_and_summary_non_stream(
        state,
        actor_user_id,
        context.session_id,
        context.user_message_id,
    )
    .await?;
    let memory_entries = load_memory_entries_for_workbench(
        state,
        actor_user_id,
        context.session_id,
        target_pet.as_ref(),
    )
    .await?;

    let workbench = build_agent_session_workbench(
        req.surface,
        target_pet.as_ref(),
        session_summary,
        memory_entries,
        recent_conversation,
    );
    let registry = Arc::new(match target_pet.as_ref() {
        Some(target_pet) => build_runtime_tool_registry(state, context.session_id, target_pet),
        None => build_public_runtime_tool_registry(),
    });
    let visible_tool_names = registry
        .list_definitions()
        .into_iter()
        .map(|tool| tool.name)
        .collect::<Vec<_>>();
    let tool_count = visible_tool_names.len();
    record_chat_workbench_built(
        context.session_id,
        context.turn_id.as_uuid(),
        context.assistant_message_id,
        &workbench,
        &visible_tool_names,
    );
    record_chat_runtime_engine_selected(
        context.session_id,
        context.assistant_message_id,
        state.runtime_engine_mode.as_str(),
        "non_stream",
        false,
        target_pet.is_some(),
        tool_count,
    );
    let tool_context = AiToolContext {
        actor_user_id,
        authorized_pet_id: target_pet.as_ref().map_or_else(Uuid::nil, |pet| pet.pet_id),
        gateway_context: ToolGatewayExecutionContext {
            session_id: Some(context.session_id),
            turn_id: Some(context.turn_id.as_uuid()),
            message_id: Some(context.assistant_message_id),
        },
        gateway_observer: Some(Arc::new(RuntimeToolGatewayObserver)),
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
    let events = session
        .prompt_with_workbench_turn_and_diagnostics_message_id(
            req.message.clone(),
            workbench,
            context.turn_id,
            context.assistant_message_id,
        )
        .await?;
    complete_from_runtime_events(events, fact_package, target_pet.is_some())
}

/// complete_from_runtime_events 聚合 Runtime 事件
pub(super) fn complete_from_runtime_events(
    events: Vec<AgentEvent>,
    fact_package: Option<AiFactPackage>,
    identity_context_tool_required: bool,
) -> Result<AiCompleteResult, AiError> {
    let mut package = fact_package.unwrap_or_else(AiFactPackage::empty);
    let mut usage = LlmUsage::default();
    let mut finish_reason = LlmFinishReason::Stop;
    let mut provider = "runtime".to_owned();
    let mut model = "primary".to_owned();
    let mut completed_text = None;
    let mut tool_names_by_call_id = HashMap::<String, String>::new();
    let mut identity_context_tool_succeeded = false;

    for event in events {
        match event {
            AgentEvent::ToolStarted {
                tool_call_id,
                tool_name,
                ..
            } => {
                tool_names_by_call_id.insert(tool_call_id, tool_name);
            }
            AgentEvent::ToolFinished {
                tool_call_id,
                status,
                fact_package,
                ..
            } => {
                let tool_name = tool_names_by_call_id.remove(&tool_call_id);
                if tool_name.as_deref() == Some("load_pet_identity_context")
                    && status == AgentToolStatus::Succeeded
                {
                    identity_context_tool_succeeded = true;
                    if let Some(fact_package) = fact_package {
                        package = *fact_package;
                    }
                }
            }
            AgentEvent::ModelCallFinished {
                finish_reason: fr,
                usage: u,
                provider: p,
                model: m,
                ..
            } => {
                usage = u;
                finish_reason = fr;
                provider = p;
                model = m;
            }
            AgentEvent::TurnFinished {
                final_text, status, ..
            } => {
                if status == AgentTurnStatus::Failed {
                    return Err(AiError::Infrastructure(
                        "runtime output guard returned failed turn".to_owned(),
                    ));
                }
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
    let verification_ctx = AiAnswerVerificationContext {
        identity_context_tool_required,
        identity_context_tool_succeeded,
    };
    let verification =
        AiAnswerVerifier::new().verify_with_context(&final_text, &package, verification_ctx);

    if verification.is_blocked() {
        return Err(AiError::Infrastructure(
            "runtime output guard returned unrepaired final answer".to_owned(),
        ));
    }

    let citations =
        maohuoban_ai_application::ai::citations::citations_for_answer(&final_text, &package);
    Ok(AiCompleteResult {
        final_text,
        content_blocks: project_pet_profile_content_blocks(&package),
        usage,
        finish_reason,
        provider,
        model,
        citations,
        verification,
    })
}
