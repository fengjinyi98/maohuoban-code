//! runtime Agent Runtime 应用层聚合模块
//! 核心职责：
//! - 暴露 LoopEngine 可替换边界
//! - 暴露 in-memory AgentSession 与 FakeLoopEngine 测试实现

mod agent_runtime_loop_engine;
mod engine;
mod fake_loop_engine;
#[path = "../Infrastructure/runtime/rig_adapter/mod.rs"]
mod rig_adapter;
mod session;
mod session_runtime;
#[path = "../Infrastructure/runtime/workbench_prompt_projection.rs"]
mod workbench_prompt_projection;

pub use agent_runtime_loop_engine::*;
pub use engine::*;
pub use fake_loop_engine::*;
pub use rig_adapter::*;
pub use session::*;
pub use session_runtime::*;
