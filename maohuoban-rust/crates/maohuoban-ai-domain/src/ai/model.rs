//! model AI 领域模型聚合
//! 核心职责：
//! - 声明 AI 领域全部 struct / enum 子模块并统一导出
//! - 保持领域层无基础设施依赖

#[path = "model/facts/fact_package.rs"]
mod fact_package;
#[path = "model/intent/intent.rs"]
mod intent;
#[path = "model/llm/llm.rs"]
mod llm;
#[path = "model/stream/proposed_action.rs"]
mod proposed_action;
#[path = "model/runtime/runtime.rs"]
mod runtime;
#[path = "model/runtime/runtime_agent_id.rs"]
mod runtime_agent_id;
#[path = "model/runtime/runtime_agent_turn_id.rs"]
mod runtime_agent_turn_id;
#[path = "model/runtime/runtime_model_label.rs"]
mod runtime_model_label;
#[path = "model/runtime/runtime_tool_confirmation_requirement.rs"]
mod runtime_tool_confirmation_requirement;
#[path = "model/runtime/runtime_tool_status.rs"]
mod runtime_tool_status;
#[path = "model/runtime/runtime_turn_status.rs"]
mod runtime_turn_status;
#[path = "model/session/session.rs"]
mod session;
#[path = "model/session/session_event.rs"]
mod session_event;
#[path = "model/session/session_turn.rs"]
mod session_turn;
#[path = "model/stream/stream.rs"]
mod stream;
#[path = "model/stream/surface.rs"]
mod surface;
#[path = "model/session/turn_replay.rs"]
mod turn_replay;
#[path = "model/verification/verification.rs"]
mod verification;

#[path = "model/pet/pet_resolution.rs"]
mod pet_resolution;
#[path = "model/pet/pet_snapshot.rs"]
mod pet_snapshot;
#[path = "model/provider/provider_capability.rs"]
mod provider_capability;
mod provider_error;
#[path = "model/stream/tool_failure.rs"]
mod tool_failure;

pub use fact_package::*;
pub use intent::*;
pub use llm::*;
pub use pet_resolution::*;
pub use pet_snapshot::*;
pub use proposed_action::*;
pub use provider_capability::*;
pub use provider_error::*;
pub use runtime::*;
pub use runtime_agent_id::*;
pub use runtime_agent_turn_id::*;
pub use runtime_model_label::*;
pub use runtime_tool_confirmation_requirement::*;
pub use runtime_tool_status::*;
pub use runtime_turn_status::*;
pub use session::*;
pub use session_event::*;
pub use session_turn::*;
pub use stream::*;
pub use surface::*;
pub use tool_failure::*;
pub use turn_replay::*;
pub use verification::*;
