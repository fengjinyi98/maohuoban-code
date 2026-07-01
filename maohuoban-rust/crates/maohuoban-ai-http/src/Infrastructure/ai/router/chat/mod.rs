//! chat AI 聊天 HTTP handler 聚合模块
//! 核心职责：
//! - 汇聚流式与非流式聊天 handler
//! - 隔离请求 DTO、标题生成和持久化辅助逻辑

mod composition {
    pub(super) mod fact_package_merge;
    pub(super) mod request;
    pub(super) mod title;
    pub(super) mod workbench_builder;
}
mod loaders {
    pub(super) mod diet_confirmation_candidate_loader;
    pub(super) mod diet_fact_loader;
    pub(super) mod food_inventory_hint_loader;
    pub(super) mod history_summary_loader;
    pub(super) mod identity_fact_loader;
}
mod responses {
    pub(super) mod gated_stream_response;
    pub(super) mod pet_resolution_stream_response;
    pub(super) mod stream_response;
}
mod non_stream_handler;
mod runtime_stream;
mod runtime_stream_bridge;
mod runtime_stream_helpers;
mod runtime_stream_projector;
mod runtime_tool_gateway_observer;
mod runtime_tools;
mod stream_handler;
mod turn_preparation;

pub use non_stream_handler::handle_chat;
pub use stream_handler::handle_chat_stream;
