//! repository AI PostgreSQL 仓储
//! 核心职责：
//! - 实现 AiSessionRepository 端口
//! - 持久化 AI 会话、消息
//! - 查询会话列表和消息详情

mod session;
mod session_rows;

pub use session::PostgresAiSessionRepository;
