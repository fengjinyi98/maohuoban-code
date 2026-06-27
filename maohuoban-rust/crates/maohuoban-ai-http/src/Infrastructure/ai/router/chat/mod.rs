//! chat AI 聊天 HTTP handler 聚合模块
//! 核心职责：
//! - 汇聚流式与非流式聊天 handler
//! - 隔离请求 DTO、标题生成和持久化辅助逻辑

mod assistant_message_persistence;
mod diet_confirmation_candidate_loader;
mod diet_fact_loader;
mod fact_package_merge;
mod food_inventory_hint_loader;
mod gated_stream_response;
mod identity_fact_loader;
mod llm_request;
mod non_stream_handler;
mod pet_resolution_stream_response;
mod request;
mod session_persistence;
mod stream_handler;
mod title;

pub use non_stream_handler::handle_chat;
pub use stream_handler::handle_chat_stream;
