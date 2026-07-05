use std::sync::Arc;

use futures_util::StreamExt;
use maohuoban_ai_application::ai::planning::{
    PlanningDiagnosticsSnapshot, StepPlanner, TaskClassifier,
};
use maohuoban_ai_application::ai::ports::ObservationWriteContext;
use maohuoban_ai_application::ai::runtime::{
    AgentRuntimeEngineFactory, AgentRuntimeEngineInput, AgentSession,
};
use maohuoban_ai_application::ai::stream::AiStreamRunContext;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, ToolGatewayExecutionContext, ToolRegistry,
};
use maohuoban_ai_domain::ai::{
    AgentEvent, AgentId, AgentSessionWorkbench, AgentTurnId, AiFactPackage, AiPetDisplaySnapshot,
    AiStreamEvent,
};
use uuid::Uuid;

use super::super::AiHttpState;
use super::super::diagnostics::{
    record_chat_content_blocks_emitted, record_chat_planning_decided,
    record_chat_render_plan_selected, record_chat_runtime_agent_event,
    record_chat_runtime_engine_selected, record_chat_workbench_built,
};
use super::composition::request::ChatStreamRequest;
use super::runtime_stream::AgentEventSseProjector;
use super::runtime_stream_helpers::{ai_error_to_sse_event, sanitize_tool_call_event};
use super::runtime_tool_gateway_observer::RuntimeToolGatewayObserver;
use super::runtime_tools::{build_public_runtime_tool_registry, build_runtime_tool_registry};
use super::visible_output_plan::plan_visible_output;

pub(super) struct RuntimeAgentStreamInput {
    pub session_id: Uuid,
    pub turn_id: AgentTurnId,
    pub message_id: Uuid,
    pub confirmation_task_id: Option<Uuid>,
    pub observation_write_context: ObservationWriteContext,
    pub actor_user_id: Uuid,
    pub target_pet: Option<AiPetDisplaySnapshot>,
    pub fact_package: Option<AiFactPackage>,
    pub context: AiStreamRunContext,
    pub workbench: AgentSessionWorkbench,
}

pub(super) fn runtime_agent_stream(
    state: &AiHttpState,
    req: &ChatStreamRequest,
    input: RuntimeAgentStreamInput,
) -> futures_util::stream::BoxStream<'static, Result<AiStreamEvent, maohuoban_ai_domain::ai::AiError>>
{
    let registry = build_runtime_registry(state, &input);
    record_runtime_stream_selection(state, &input, registry.as_ref());
    let visible_output_plan = plan_visible_output(req.surface, input.target_pet.as_ref());
    let engine = build_runtime_engine(state, &input, registry);
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
    let activity_pet_name = activity_pet_name(input.target_pet.as_ref());
    let identity_context_tool_required = input.target_pet.is_some();
    let surface = req.surface;
    let has_target_pet = input.target_pet.is_some();

    async_stream::stream! {
        let AiStreamRunContext {
            chat_session_id,
            message_id: started_message_id,
            title,
            target_pet,
            initial_events,
            ..
        } = context;
        yield Ok(AiStreamEvent::MessageStarted {
            chat_session_id,
            message_id: started_message_id,
            target_pet,
            title,
        });

        for event in initial_events {
            yield Ok(sanitize_tool_call_event(event, &activity_pet_name));
        }

        let mut projector = AgentEventSseProjector::new(
            message_id,
            fact_package,
            &activity_pet_name,
            identity_context_tool_required,
            visible_output_plan,
            );
        let mut agent_stream =
            session.into_prompt_stream_with_workbench_turn_and_diagnostics_message_id(
                user_message,
                workbench,
                input.turn_id,
                message_id,
            );
        let mut render_plan_recorded = false;
        while let Some(result) = agent_stream.next().await {
            match result {
                Ok(agent_event) => {
                    record_agent_event_diagnostic(chat_session_id, message_id, &agent_event);
                    let projected_events = projector.project(agent_event);
                    for event in projected_events {
                        if !render_plan_recorded
                            && is_terminal_message_event(&event)
                        {
                            record_projected_render_plan(
                                chat_session_id,
                                message_id,
                                surface,
                                has_target_pet,
                                &projector,
                            );
                            render_plan_recorded = true;
                        }
                        if let AiStreamEvent::ContentBlockDelta { content_blocks }
                        | AiStreamEvent::AnswerCompleted { content_blocks, .. }
                        | AiStreamEvent::MessageCompleted { content_blocks, .. } = &event
                            && !content_blocks.is_empty()
                        {
                            record_chat_content_blocks_emitted(
                                chat_session_id,
                                message_id,
                                event.event_name(),
                                content_blocks,
                            );
                        }
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

fn record_agent_event_diagnostic(
    chat_session_id: Uuid,
    message_id: Uuid,
    agent_event: &AgentEvent,
) {
    let event_name = agent_event.event_name().to_owned();
    let payload = serde_json::to_value(agent_event).unwrap_or_else(|_| serde_json::json!({}));
    record_chat_runtime_agent_event(chat_session_id, message_id, &event_name, &payload);
}

fn is_terminal_message_event(event: &AiStreamEvent) -> bool {
    matches!(
        event,
        AiStreamEvent::AnswerCompleted { .. } | AiStreamEvent::MessageCompleted { .. }
    )
}

fn record_projected_render_plan(
    session_id: Uuid,
    message_id: Uuid,
    surface: maohuoban_ai_domain::ai::AiConversationSurface,
    has_target_pet: bool,
    projector: &AgentEventSseProjector,
) {
    let allowed_block_kinds = projector.effective_visible_output_plan().block_kind_codes();
    record_chat_render_plan_selected(
        session_id,
        message_id,
        surface,
        has_target_pet,
        &allowed_block_kinds,
    );
}

fn build_runtime_registry(
    state: &AiHttpState,
    input: &RuntimeAgentStreamInput,
) -> Arc<ToolRegistry> {
    Arc::new(match input.target_pet.as_ref() {
        Some(target_pet) => build_runtime_tool_registry(state, input.session_id, target_pet),
        None => build_public_runtime_tool_registry(),
    })
}

fn record_runtime_stream_selection(
    state: &AiHttpState,
    input: &RuntimeAgentStreamInput,
    registry: &ToolRegistry,
) {
    let tool_definitions = registry.list_definitions();
    let visible_tool_names = tool_definitions
        .iter()
        .map(|tool| tool.name.clone())
        .collect::<Vec<_>>();
    record_chat_workbench_built(
        input.session_id,
        input.turn_id.as_uuid(),
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
        visible_tool_names.len(),
    );
    let selected_pet_id = input.workbench.context_pack.selected_pet.as_ref();
    let confirmation_task_present = input
        .workbench
        .context_pack
        .pending_confirmation_task
        .is_some();
    let task_type = TaskClassifier::classify_runtime_with_context(
        selected_pet_id.is_some(),
        confirmation_task_present,
        input
            .observation_write_context
            .is_abnormal_episode_followup(),
    );
    let plan = StepPlanner::plan(task_type);
    let snapshot =
        PlanningDiagnosticsSnapshot::new(input.session_id, input.turn_id, input.message_id, &plan);
    record_chat_planning_decided(&snapshot);
}

fn build_runtime_engine(
    state: &AiHttpState,
    input: &RuntimeAgentStreamInput,
    registry: Arc<ToolRegistry>,
) -> Box<dyn maohuoban_ai_application::ai::runtime::LoopEngine> {
    let tool_context = AiToolContext {
        actor_user_id: input.actor_user_id,
        authorized_pet_id: input
            .target_pet
            .as_ref()
            .map_or_else(Uuid::nil, |pet| pet.pet_id),
        gateway_context: ToolGatewayExecutionContext {
            session_id: Some(input.session_id),
            turn_id: Some(input.turn_id.as_uuid()),
            message_id: Some(input.message_id),
            confirmation_task_id: input.confirmation_task_id.map(|id| id.to_string()),
        },
        observation_write_context: input.observation_write_context.clone(),
        gateway_observer: Some(Arc::new(RuntimeToolGatewayObserver)),
    };
    AgentRuntimeEngineFactory::new(state.runtime_engine_mode).build(AgentRuntimeEngineInput {
        provider: state.llm_provider.clone(),
        registry,
        tool_context,
        fact_package: input.fact_package.clone(),
    })
}

fn activity_pet_name(target_pet: Option<&AiPetDisplaySnapshot>) -> String {
    target_pet.map_or_else(|| "宠物".to_owned(), |pet| pet.pet_name.clone())
}
