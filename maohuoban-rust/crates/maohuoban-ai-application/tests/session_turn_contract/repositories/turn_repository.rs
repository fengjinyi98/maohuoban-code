use std::sync::Mutex;

use async_trait::async_trait;
use maohuoban_ai_application::ai::ports::SessionTurnRepository;
use maohuoban_ai_domain::ai::{AiError, AiResult, AiSessionTurn, AiSessionTurnStatus};
use uuid::Uuid;

/// `InMemoryTurnRepository` 内存 Turn 账本仓储
/// 核心职责：
/// - 为合同测试提供可读取回写的 Turn 存储
/// - 验证 `SessionTurnRepository` 端口合同
pub struct InMemoryTurnRepository {
    turns: Mutex<Vec<AiSessionTurn>>,
}

impl InMemoryTurnRepository {
    pub fn new() -> Self {
        Self {
            turns: Mutex::new(Vec::new()),
        }
    }
}

#[async_trait]
impl SessionTurnRepository for InMemoryTurnRepository {
    async fn insert_turn(&self, turn: &AiSessionTurn) -> AiResult<()> {
        self.turns.lock().expect("lock").push(turn.clone());
        Ok(())
    }

    async fn update_turn_status(
        &self,
        turn_id: Uuid,
        status: AiSessionTurnStatus,
        assistant_message_id: Option<Uuid>,
        finish_reason: Option<&str>,
        error_code: Option<&str>,
        retryable: Option<bool>,
    ) -> AiResult<()> {
        let mut turns = self.turns.lock().expect("lock");
        for turn in turns.iter_mut() {
            if turn.id == turn_id {
                turn.status = status;
                if assistant_message_id.is_some() {
                    turn.assistant_message_id = assistant_message_id;
                }
                turn.finish_reason = finish_reason.map(ToOwned::to_owned);
                turn.error_code = error_code.map(ToOwned::to_owned);
                turn.retryable = retryable;
                if status.is_terminal() {
                    turn.finished_at = Some(chrono::Utc::now());
                }
                return Ok(());
            }
        }
        Err(AiError::NotFound("turn not found".to_owned()))
    }

    async fn get_turn(&self, turn_id: Uuid) -> AiResult<Option<AiSessionTurn>> {
        Ok(self
            .turns
            .lock()
            .expect("lock")
            .iter()
            .find(|t| t.id == turn_id)
            .cloned())
    }

    async fn list_turns_by_session(&self, session_id: Uuid) -> AiResult<Vec<AiSessionTurn>> {
        Ok(self
            .turns
            .lock()
            .expect("lock")
            .iter()
            .filter(|t| t.session_id == session_id)
            .cloned()
            .collect())
    }
}
