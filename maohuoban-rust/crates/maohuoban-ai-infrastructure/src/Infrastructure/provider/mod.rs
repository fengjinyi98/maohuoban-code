//! provider AI 基础设施 Provider 实现
//! 核心职责：
//! - 实现 OpenAI 兼容 LLM Provider
//! - 密钥只在 infrastructure 内读取和使用，不进入 domain/application/日志

pub mod config;
pub mod openai_compatible;
pub mod sse;

pub use config::OpenAiCompatibleConfig;
pub use openai_compatible::OpenAiCompatibleLlmProvider;
pub use sse::parse_sse_stream;
