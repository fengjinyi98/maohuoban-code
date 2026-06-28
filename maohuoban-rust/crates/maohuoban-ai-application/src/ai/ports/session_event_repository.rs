// MHB_STRUCTURE_EXEMPTION: WT04 目标文档冻结该 Rust application port 路径，保持现有 AI crate 模块形态。
use async_trait::async_trait;
use maohuoban_ai_domain::ai::{AgentSessionEventEntry, AgentTurnReplay, AiResult};
use uuid::Uuid;

/// SessionEventRepository Agent session event 仓储端口
/// 核心职责：
/// - 追加写入 runtime session event
/// - 按 session / turn 读取事件并支持 replay 序列断言
#[async_trait]
pub trait SessionEventRepository: Send + Sync {
    /// append 追加写入一个事件 entry
    async fn append(&self, entry: &AgentSessionEventEntry) -> AiResult<()>;

    /// list_by_session 按 session 读取事件，按写入时间升序
    async fn list_by_session(&self, session_id: Uuid) -> AiResult<Vec<AgentSessionEventEntry>>;

    /// list_by_turn 按 turn 读取事件，按写入时间升序
    async fn list_by_turn(&self, turn_id: Uuid) -> AiResult<Vec<AgentSessionEventEntry>>;

    /// replay_turn 读取单 turn replay 视图
    async fn replay_turn(&self, turn_id: Uuid) -> AiResult<AgentTurnReplay> {
        let events = self.list_by_turn(turn_id).await?;
        Ok(AgentTurnReplay::new(turn_id, events))
    }
}
