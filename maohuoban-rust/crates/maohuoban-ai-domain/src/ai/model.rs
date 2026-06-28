//! model AI 领域模型聚合
//! 核心职责：
//! - 声明 AI 领域全部 struct / enum 子模块并统一导出
//! - 保持领域层无基础设施依赖
// MHB_STRUCTURE_EXEMPTION: 既有 AI domain 聚合入口，WT04 仅追加 frozen session event export。

mod fact_package;
mod intent;
mod llm;
mod proposed_action;
mod runtime;
mod session;
mod session_event;
mod stream;
mod surface;
mod turn_replay;
mod verification;

mod pet_resolution;
mod pet_snapshot;
mod provider_error;

pub use fact_package::*;
pub use intent::*;
pub use llm::*;
pub use pet_resolution::*;
pub use pet_snapshot::*;
pub use proposed_action::*;
pub use runtime::*;
pub use provider_error::*;
pub use session::*;
pub use session_event::*;
pub use stream::*;
pub use surface::*;
pub use turn_replay::*;
pub use verification::*;
