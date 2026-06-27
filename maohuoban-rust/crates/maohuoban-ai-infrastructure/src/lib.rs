#![allow(
    clippy::cast_possible_truncation,
    clippy::cast_possible_wrap,
    clippy::cast_sign_loss,
    clippy::doc_markdown,
    clippy::missing_errors_doc
)]

//! maohuoban-ai-infrastructure 毛球 Agent AI 基础设施层
//! 核心职责：
//! - 实现 OpenAI 兼容 LLM Provider、PostgreSQL AI 仓储、审计仓储、SSE 解析
//! - 密钥只在 infrastructure 内读取和使用，不进入 domain/application/日志

#[path = "Infrastructure/provider/mod.rs"]
pub mod provider;
pub mod repository;
