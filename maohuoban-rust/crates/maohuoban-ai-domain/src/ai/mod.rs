//! ai 毛球 Agent 领域聚合模块
//! 核心职责：
//! - 汇聚 AI 领域错误、模型和流式事件定义
//! - 为 application / infrastructure / http 层提供稳定领域类型

mod error;
mod model;

pub use error::{AiError, AiResult};
pub use model::*;
