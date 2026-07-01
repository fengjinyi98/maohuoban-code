// MHB_STRUCTURE_EXEMPTION: openai mod.rs 是 OpenAI 兼容协议子模块聚合文件
//! openai OpenAI 兼容协议实现子模块
//! 核心职责：
//! - 聚合 OpenAI 兼容协议的请求体、响应解析、流解码和诊断

mod body;
mod diagnostics;
pub mod provider;
mod response;
pub mod sse;
mod stream_event;
mod stream_stats;
mod tool_schema;

pub use provider::OpenAiCompatibleLlmProvider;
pub use sse::{parse_sse_buffer, parse_sse_stream};
