//! repository AI PostgreSQL 仓储
//! 核心职责：
//! - 实现 AiSessionRepository 端口
//! - 持久化 AI 会话、消息
//! - 查询会话列表和消息详情
// MHB_STRUCTURE_EXEMPTION: 既有 AI infrastructure repository 聚合入口，WT04 仅追加 session event repository export。

mod session;
mod session_event;
mod session_rows;

pub use session::PostgresAiSessionRepository;
pub use session_event::PostgresSessionEventRepository;
