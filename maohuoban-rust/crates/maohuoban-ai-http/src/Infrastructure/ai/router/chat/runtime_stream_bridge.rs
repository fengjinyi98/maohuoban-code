use std::sync::Arc;

use futures_util::StreamExt;
use maohuoban_ai_application::ai::runtime::{
    AgentRuntimeEngineFactory, AgentRuntimeEngineInput, AgentSession,
};
use maohuoban_ai_application::ai::stream::AiStreamRunContext;
use maohuoban_ai_application::ai::tools::{AiToolContext, ToolRegistry};
use maohuoban_ai_domain::ai::{
    AgentId, AgentSessionWorkbench, AiFactPackage, AiPetDisplaySnapshot, AiStreamEvent,
};
use uuid::Uuid;

use super::super::AiHttpState;
use super::super::diagnostics::{
    record_chat_runtime_agent_event, record_chat_runtime_engine_selected,
    record_chat_workbench_built,
};
use super::composition::request::ChatStreamRequest;
use super::runtime_stream::AgentEventSseProjector;
use super::runtime_stream_helpers::{ai_error_to_sse_event, sanitize_legacy_tool_call_event};
use super::runtime_tools::build_runtime_tool_registry;

pub(super) struct RuntimeProviderStreamInput {
    pub session_id: Uuid,
    pub message_id: Uuid,
    pub actor_user_id: Uuid,
    pub target_pet: Option<AiPetDisplaySnapshot>,
    pub fact_package: Option<AiFactPackage>,
    pub context: AiStreamRunContext,
    pub workbench: AgentSessionWorkbench,
}

pub(super) fn runtime_provider_stream(
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
    let visible_tool_names = registry
        .list_definitions()
        .into_iter()
        .map(|tool| tool.name)
        .collect::<Vec<_>>();
    let tool_count = visible_tool_names.len();
    record_chat_workbench_built(
        input.session_id,
        input.message_id,
        &input.workbench,
        &visible_tool_names,
    );
    record_chat_runtime_engine_selected(
        input.session_id,
        input.message_id,
        state.runtime_engine_mode.as_str(),
        "stream",
        true,
        input.target_pet.is_some(),
        tool_count,
    );
    let tool_context = AiToolContext {
        actor_user_id: input.actor_user_id,
        authorized_pet_id: input
            .target_pet
            .as_ref()
            .map_or_else(Uuid::nil, |pet| pet.pet_id),
    };
    let engine =
        AgentRuntimeEngineFactory::new(state.runtime_engine_mode).build(AgentRuntimeEngineInput {
            provider,
            registry,
            tool_context,
            fact_package: input.fact_package.clone(),
        });
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
        let identity_context_tool_required = target_pet.is_some();

        yield Ok(AiStreamEvent::MessageStarted {
            chat_session_id,
            message_id: started_message_id,
            target_pet,
            title,
        });

        for event in initial_events {
            yield Ok(sanitize_legacy_tool_call_event(event, &activity_pet_name));
        }

        let mut projector = AgentEventSseProjector::new(
            message_id,
            fact_package,
            &activity_pet_name,
            identity_context_tool_required,
        );
        let mut agent_stream = session.into_prompt_stream_with_workbench_diagnostics_message_id(
            user_message,
            workbench,
            message_id,
        );
        while let Some(result) = agent_stream.next().await {
            match result {
                Ok(agent_event) => {
                    let event_name = agent_event.event_name().to_owned();
                    let payload =
                        serde_json::to_value(&agent_event).unwrap_or_else(|_| serde_json::json!({}));
                    record_chat_runtime_agent_event(
                        chat_session_id,
                        message_id,
                        &event_name,
                        payload,
                    );
                    let projected_events = projector.project(agent_event);
                    for event in projected_events {
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
