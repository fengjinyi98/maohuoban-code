#[path = "diagnostics/shared/helpers.rs"]
mod helpers;
#[path = "diagnostics/ingress/ingress_auth.rs"]
mod ingress_auth;
#[path = "diagnostics/provider/provider_finalizer.rs"]
mod provider_finalizer;
#[path = "diagnostics/provider/provider_gate.rs"]
mod provider_gate;
#[path = "diagnostics/runtime/runtime_workbench.rs"]
mod runtime_workbench;
#[path = "diagnostics/stream/stream_events.rs"]
mod stream_events;

pub(crate) use super::history_diagnostics::{
    record_history_messages_loaded, record_history_mutation_completed,
    record_history_sessions_loaded,
};
pub(crate) use ingress_auth::{
    record_chat_non_stream_auth_failed, record_chat_non_stream_auth_succeeded,
    record_chat_non_stream_ingress_received, record_chat_stream_auth_failed,
    record_chat_stream_auth_succeeded, record_chat_stream_ingress_received,
    record_chat_stream_request_received,
};
pub(crate) use provider_finalizer::{record_chat_finalizer_completed, record_chat_provider_error};
pub(crate) use provider_gate::{
    record_chat_gate_decided, record_chat_provider_started, record_chat_runtime_engine_selected,
};
pub(crate) use runtime_workbench::{record_chat_render_plan_selected, record_chat_workbench_built};
pub(crate) use stream_events::{
    record_chat_content_blocks_emitted, record_chat_planning_decided,
    record_chat_runtime_agent_event, record_chat_stream_event_emitted,
};
