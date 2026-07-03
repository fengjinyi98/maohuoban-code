use maohuoban_ai_domain::ai::{
    AgentEvent, AgentId, AgentTurnId, AiConversationSurface, ModelLabel, ProviderErrorCategory,
};
use uuid::Uuid;

pub fn replay_agent_event(event_name: &str, turn_id: AgentTurnId) -> AgentEvent {
    match event_name {
        "turn_started" => AgentEvent::TurnStarted {
            turn_id,
            chat_session_id: Uuid::new_v4(),
            agent_id: AgentId::main_pet_care_agent(),
            surface: AiConversationSurface::HomePrivate,
            engine_mode: "openai".to_owned(),
        },
        "model_call_started" => AgentEvent::ModelCallStarted {
            turn_id,
            model_label: ModelLabel::Primary,
            tool_count: 0,
            engine_mode: "openai".to_owned(),
        },
        "provider_error" => AgentEvent::ProviderError {
            turn_id,
            category: ProviderErrorCategory::NotConfigured,
            retryable: false,
            engine_mode: "openai".to_owned(),
        },
        "turn_failed" => AgentEvent::TurnFailed {
            turn_id,
            error_code: "ai.provider.not_configured".to_owned(),
            retryable: false,
            engine_mode: "openai".to_owned(),
            termination_reason: None,
        },
        event => panic!("unsupported replay fixture event {event}"),
    }
}
