use thiserror::Error;

/// `AgentFollowupSchedulerError` Agent 主动追踪调度错误
/// 核心职责：
/// - 汇总调度器运行时数据库错误
/// - 保持后台任务入口错误输出稳定
#[derive(Debug, Error)]
pub enum AgentFollowupSchedulerError {
    #[error("database error: {0}")]
    Database(#[from] sqlx::Error),
}
