//! ai 毛球 Agent 应用层聚合模块
//! 核心职责：
//! - 汇聚端口、服务、意图闸门、宠物解析、工具、上下文、Prompt、校验和流式 pipeline

pub mod context;
pub mod intent;
pub mod model_router;
pub mod pet_resolver;
pub mod policy;
pub mod ports;
pub mod prompt;
pub mod runtime;
pub mod stream;
pub mod tools;
pub mod verifier;
