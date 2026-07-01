//! finalizer Agent 终态收口协议落点
//! 核心职责：
//! - 承接 TurnTerminalOutput 并统一收口 turn 终态
//! - 固定同步关键写入和异步派生后处理边界

mod async_failure;
mod async_job;
mod async_job_kind;
mod receipt;
mod service;
mod session_header_update;
mod store;
mod synchronous_write;
mod terminal_output;

pub use async_failure::FinalizerAsyncFailure;
pub use async_job::FinalizerAsyncJob;
pub use async_job_kind::FinalizerAsyncJobKind;
pub use receipt::FinalizationReceipt;
pub use service::TurnFinalizer;
pub use session_header_update::FinalizerSessionHeaderUpdate;
pub use store::FinalizerStore;
pub use synchronous_write::FinalizerSynchronousWrite;
pub use terminal_output::TurnTerminalOutput;
