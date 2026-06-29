//! guardrail per-turn 工具循环 guardrail
//! 核心职责：
//! - ToolCallGuardrail：检测重复失败、同参重复、只读工具无进展
//! - GuardrailDecision：区分软提醒（SoftReminder）和硬停止（HardStop）

mod controller;
mod decision;

pub use controller::{ToolCallGuardrail, ToolCallRecord};
pub use decision::GuardrailDecision;
