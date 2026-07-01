//! repository AI PostgreSQL 仓储
//! 核心职责：
//! - 实现 AiSessionRepository 端口
//! - 持久化 AI 会话、消息
//! - 查询会话列表和消息详情
// MHB_STRUCTURE_EXEMPTION: 既有 AI infrastructure repository 聚合入口。

mod chat_turn_transaction;
mod memory;
mod memory_candidate;
mod session;
mod session_event;
mod session_rows;
mod session_summary;
mod session_turn;

pub use chat_turn_transaction::PostgresChatTurnTransaction;
pub use memory::PostgresMemoryRepository;
pub use memory_candidate::PostgresMemoryCandidateRepository;
pub use session::PostgresAiSessionRepository;
pub use session_event::PostgresSessionEventRepository;
pub use session_summary::PostgresSessionSummaryRepository;
pub use session_turn::PostgresSessionTurnRepository;
