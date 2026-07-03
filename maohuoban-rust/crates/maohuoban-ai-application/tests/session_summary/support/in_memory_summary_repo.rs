use std::sync::Mutex;

use maohuoban_ai_application::ai::ports::SessionSummaryRepository;
use maohuoban_ai_domain::ai::{AiResult, SessionSummary};
use uuid::Uuid;

/// `InMemorySummaryRepo` 内存会话摘要仓储
/// 核心职责：
/// - 为压缩流程测试保存摘要快照
/// - 验证摘要写入、读取和 supersede 行为
pub struct InMemorySummaryRepo {
    summaries: Mutex<Vec<SessionSummary>>,
}

impl InMemorySummaryRepo {
    pub fn new() -> Self {
        Self {
            summaries: Mutex::new(Vec::new()),
        }
    }
}

#[async_trait::async_trait]
impl SessionSummaryRepository for InMemorySummaryRepo {
    async fn insert_summary(&self, summary: &SessionSummary) -> AiResult<()> {
        self.summaries.lock().expect("lock").push(summary.clone());
        Ok(())
    }

    async fn get_active_summary(&self, chat_session_id: Uuid) -> AiResult<Option<SessionSummary>> {
        let summaries = self.summaries.lock().expect("lock");
        Ok(summaries
            .iter()
            .rfind(|s| s.chat_session_id == chat_session_id && s.is_active())
            .cloned())
    }

    async fn supersede_previous_summaries(
        &self,
        chat_session_id: Uuid,
        superseded_at: chrono::DateTime<chrono::Utc>,
    ) -> AiResult<()> {
        let mut summaries = self.summaries.lock().expect("lock");
        for s in summaries.iter_mut() {
            if s.chat_session_id == chat_session_id && s.is_active() {
                s.superseded_at = Some(superseded_at);
            }
        }
        Ok(())
    }
}
