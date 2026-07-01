//! skill Agent Skill 运行时协议落点
//! 核心职责：
//! - 承接后续 SkillDefinition、SkillMatcher 和 SkillBundle
//! - 作为 WT09 内置 skill runtime 实现的模块边界

mod builtin_runtime;
mod diagnostics_snapshot;
mod match_input;
mod matcher;
mod runtime_diagnostics;
mod skill_bundle;
mod toolset_policy;
mod workflow_policy;

pub use builtin_runtime::BuiltinSkillRuntime;
pub use diagnostics_snapshot::SkillDiagnosticsSnapshot;
pub use match_input::SkillMatchInput;
pub use matcher::SkillMatcher;
pub(crate) use runtime_diagnostics::SkillRuntimeDiagnostics;
pub use skill_bundle::SkillBundle;
pub use toolset_policy::SkillToolsetPolicy;
pub use workflow_policy::SkillWorkflowPolicy;
