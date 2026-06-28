//! policy Agent 工具策略裁决
//! 核心职责：
//! - 在工具执行前根据工具 metadata 和上下文裁决
//! - 对未知工具、越权目标、写入和高风险动作返回拒绝或确认需求

mod decision;
mod guard;

pub use decision::PolicyDecision;
pub use guard::PolicyGuard;
