//! model AI 领域模型聚合
//! 核心职责：
//! - 声明 AI 领域全部 struct / enum 子模块并统一导出
//! - 保持领域层无基础设施依赖

mod fact_package;
mod intent;
mod llm;
mod proposed_action;
mod runtime;
mod runtime_agent_id;
mod runtime_agent_turn_id;
mod runtime_model_label;
mod runtime_tool_confirmation_requirement;
mod runtime_tool_status;
mod runtime_turn_status;
mod session;
mod session_event;
mod session_turn;
mod stream;
mod surface;
mod turn_replay;
mod verification;

mod pet_resolution;
mod pet_snapshot;
mod provider_capability;
mod provider_error;
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
