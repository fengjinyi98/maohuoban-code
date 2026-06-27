#![allow(clippy::doc_markdown, clippy::missing_errors_doc)]

//! maohuoban-ai-http 毛球 Agent AI HTTP 层
//! 核心职责：
//! - 承载 /api/v1/ai/chat、/api/v1/ai/chat/stream、历史接口的 HTTP DTO 和路由
//! - 用户身份只来自后端 token，不信任请求体 actor_user_id 字段

#[path = "Infrastructure/ai/mod.rs"]
pub mod ai;
