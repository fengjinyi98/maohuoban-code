//! ai 毛球 Agent 应用层聚合模块
//! 核心职责：
//! - 汇聚端口、服务、意图闸门、宠物解析、工具、上下文、Prompt、校验和流式 pipeline

pub mod citations;
pub mod context;
pub mod conversation_history;
pub mod fact_projection;
pub mod intent;
pub mod memory;
pub mod model_router;
pub mod output;
pub mod pet_resolver;
pub mod policy;
pub mod ports;
pub mod prompt;
pub mod runtime;
pub mod session_summary;
pub mod stream;
pub mod tools;
pub mod turn_context;
pub mod verifier;
