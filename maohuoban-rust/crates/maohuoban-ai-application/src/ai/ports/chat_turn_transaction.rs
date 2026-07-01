use async_trait::async_trait;
use maohuoban_ai_domain::ai::{
    AiChatSession, AiCitation, AiMessage, AiResult, AiSessionTurn, AiSessionTurnStatus,
};
use uuid::Uuid;

use super::AiRequestGateLog;

/// IngressTxInput Ingress 事务输入
/// 核心职责：
/// - 承载 Ingress 阶段全部持久化数据
/// - 确保 session、user message、turn、gate log 在同一事务内写入
pub struct IngressTxInput<'a> {
    pub session: &'a AiChatSession,
    pub user_message: &'a AiMessage,
    pub turn: &'a AiSessionTurn,
    pub gate_log: &'a AiRequestGateLog,
}

/// FinalizerTxInput Finalizer 事务输入
/// 核心职责：
/// - 承载 Finalizer 阶段全部持久化数据
/// - 确保 assistant message、citations、turn 终态在同一事务内写入
pub struct FinalizerTxInput<'a> {
    pub assistant_message: &'a AiMessage,
    pub citations: &'a [AiCitation],
    pub turn_id: Uuid,
    pub turn_status: AiSessionTurnStatus,
    pub assistant_message_id: Option<Uuid>,
    pub finish_reason: Option<&'a str>,
    pub error_code: Option<&'a str>,
    pub retryable: Option<bool>,
}

/// ChatTurnTransactionPort 聊天轮次事务端口
/// 核心职责：
/// - 提供 Ingress 阶段的原子化持久化（session + user message + turn + gate log）
/// - 提供 Finalizer 阶段的原子化持久化（assistant message + citations + turn 终态）
/// - 消除多次独立仓储调用导致的中间态不一致风险
#[async_trait]
pub trait ChatTurnTransactionPort: Send + Sync {
    /// persist_ingress_tx 在单个数据库事务内写入 Ingress 阶段全部数据
    async fn persist_ingress_tx(&self, input: &IngressTxInput<'_>) -> AiResult<()>;

    /// persist_finalizer_tx 在单个数据库事务内写入 Finalizer 阶段全部数据
    async fn persist_finalizer_tx(&self, input: &FinalizerTxInput<'_>) -> AiResult<()>;
}
