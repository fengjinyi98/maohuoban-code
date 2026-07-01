use async_trait::async_trait;
use maohuoban_ai_domain::ai::{AiResult, AiSessionTurn, AiSessionTurnStatus};
use uuid::Uuid;

/// SessionTurnRepository Turn 账本仓储端口
/// 核心职责：
/// - 持久化 turn 行并在终态时更新
/// - 按 session 读取 turn 列表，按 turn 读取单行
/// - application 只依赖该 trait，不感知具体数据库实现
#[async_trait]
pub trait SessionTurnRepository: Send + Sync {
    /// insert_turn 在 Ingress 阶段插入 turn 行
    async fn insert_turn(&self, turn: &AiSessionTurn) -> AiResult<()>;

    /// update_turn_status 更新 turn 终态
    /// 核心职责：
    /// - 在 Finalizer 阶段唯一收口 turn 终态
    /// - 写入 status、finished_at、assistant_message_id、finish_reason、error_code、retryable
    async fn update_turn_status(
        &self,
        turn_id: Uuid,
        status: AiSessionTurnStatus,
        assistant_message_id: Option<Uuid>,
        finish_reason: Option<&str>,
        error_code: Option<&str>,
        retryable: Option<bool>,
    ) -> AiResult<()>;

    /// get_turn 读取单个 turn
    async fn get_turn(&self, turn_id: Uuid) -> AiResult<Option<AiSessionTurn>>;

    /// list_turns_by_session 按 session 读取 turn 列表
    /// 核心职责：
    /// - 按 started_at 升序返回该 session 下所有 turn
    /// - 为会话详情页和 replay 提供主链读取入口
    async fn list_turns_by_session(&self, session_id: Uuid) -> AiResult<Vec<AiSessionTurn>>;
}
