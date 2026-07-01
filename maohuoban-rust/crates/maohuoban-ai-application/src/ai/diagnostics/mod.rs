//! diagnostics AI 诊断基线模块
//! 核心职责：
//! - 固定 Agent Runtime 诊断字段和 correlation id 规范
//! - 提供开发期正文观测所需的认证字段脱敏 helper

mod correlation;
mod redaction;

pub use correlation::*;
pub use redaction::*;
