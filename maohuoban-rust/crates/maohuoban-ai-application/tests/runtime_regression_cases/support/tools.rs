#[path = "tools/always_fail_tool.rs"]
mod always_fail_tool;
#[path = "tools/echo_identity_tool.rs"]
mod echo_identity_tool;

pub use always_fail_tool::AlwaysFailTool;
pub use echo_identity_tool::EchoIdentityTool;
