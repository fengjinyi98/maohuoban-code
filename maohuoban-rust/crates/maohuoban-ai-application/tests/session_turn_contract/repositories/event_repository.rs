use std::sync::Mutex;

use async_trait::async_trait;
use maohuoban_ai_application::ai::ports::SessionEventRepository;
use maohuoban_ai_domain::ai::{AgentSessionEventEntry, AgentTurnReplay, AiResult};
use uuid::Uuid;

/// `InMemoryEventRepository` 内存 Session Event 仓储
/// 核心职责：
/// - 为 replay 合同测试提供 append-only 事件存储
/// - 验证 `SessionEventRepository` 端口合同
pub struct InMemoryEventRepository {
    events: Mutex<Vec<AgentSessionEventEntry>>,
}

impl InMemoryEventRepository {
    pub fn new() -> Self {
        Self {
            events: Mutex::new(Vec::new()),
        }
    }
}

#[async_trait]
impl SessionEventRepository for InMemoryEventRepository {
    async fn append(&self, entry: &AgentSessionEventEntry) -> AiResult<()> {
        self.events.lock().expect("lock").push(entry.clone());
        Ok(())
    }

    async fn list_by_session(&self, session_id: Uuid) -> AiResult<Vec<AgentSessionEventEntry>> {
        Ok(self
            .events
            .lock()
            .expect("lock")
            .iter()
            .filter(|e| e.session_id == session_id)
            .cloned()
            .collect())
    }

    async fn list_by_turn(&self, turn_id: Uuid) -> AiResult<Vec<AgentSessionEventEntry>> {
        Ok(self
            .events
            .lock()
            .expect("lock")
            .iter()
            .filter(|e| e.turn_id == turn_id)
            .cloned()
            .collect())
    }

    async fn replay_turn(&self, turn_id: Uuid) -> AiResult<AgentTurnReplay> {
        let events = self.list_by_turn(turn_id).await?;
        Ok(AgentTurnReplay::new(turn_id, events))
    }
}
