//! chat AI 聊天 HTTP handler 聚合模块
//! 核心职责：
//! - 汇聚流式与非流式聊天 handler
//! - 隔离请求 DTO、标题生成和持久化辅助逻辑

mod composition {
    pub(super) mod request;
    pub(super) mod title;
    pub(super) mod workbench_builder;
}
mod content_block_projector;
mod fact_package_merge;
mod loaders {
    pub(super) mod history_summary_loader;
}
mod persistence {
    pub(super) mod finalizer_store;
}
mod responses {
    pub(super) mod gated_stream_response;
    pub(super) mod pet_resolution_stream_response;
    pub(super) mod stream_response;
}
mod non_stream;
mod runtime_activity_text;
mod runtime_stream;
mod runtime_stream_bridge;
mod runtime_stream_helpers;
mod runtime_stream_projector;
mod runtime_tool_gateway_observer;
mod runtime_tools;
mod stream_handler;
mod turn_preparation;
mod visible_output_plan;

pub use non_stream::handle_chat;
pub use stream_handler::handle_chat_stream;
