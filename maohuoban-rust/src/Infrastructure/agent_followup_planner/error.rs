use maohuoban_ai_domain::ai::AiError;
use thiserror::Error;

/// `AgentFollowupPlannerError` 异常主动追踪规划错误
/// 核心职责：
/// - 统一表达数据库、Agent Runtime 和业务规划失败
/// - 保持后台 job 对外返回稳定错误类型
#[derive(Debug, Error)]
pub enum AgentFollowupPlannerError {
    #[error("database error: {0}")]
    Database(#[from] sqlx::Error),
    #[error("agent runtime error: {0}")]
    AgentRuntime(#[from] AiError),
}
