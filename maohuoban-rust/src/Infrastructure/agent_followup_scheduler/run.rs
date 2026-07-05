use chrono::{DateTime, Utc};
use sqlx::PgPool;

use super::{AgentFollowupSchedulerError, AgentFollowupSchedulerRunResult};

/// `run_once` 执行一次 Agent 主动追踪到期投影
/// 核心职责：
/// - 调用数据库调度函数领取到期追踪计划
/// - 将 due plan 投影为首页站内轻提醒
///
/// # Errors
/// 当数据库调度函数执行失败时返回错误。
pub async fn run_once(
    pool: &PgPool,
    now_at: DateTime<Utc>,
) -> Result<AgentFollowupSchedulerRunResult, AgentFollowupSchedulerError> {
    let projected_hints: i64 =
        sqlx::query_scalar(r"SELECT project_due_agent_proactive_followups($1::timestamptz)")
            .bind(now_at)
            .fetch_one(pool)
            .await?;

    Ok(AgentFollowupSchedulerRunResult { projected_hints })
}
