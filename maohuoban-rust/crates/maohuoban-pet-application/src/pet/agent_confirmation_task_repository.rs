// AgentConfirmationTaskRepository 结构化确认任务仓储端口
// 核心职责：
// - 定义 agent_confirmation_tasks 持久化操作的端口 trait
// - 支持创建、按宠物读取 pending 任务、更新状态、按 ID 读取

use async_trait::async_trait;
use maohuoban_pet_domain::pet::{AgentConfirmationTask, PetResult};
use uuid::Uuid;

/// AgentConfirmationTaskRepository 结构化确认任务仓储端口
/// 核心职责：
/// - 为 AgentConfirmationTask 提供持久化抽象
/// - 让 PostgreSQL、in-memory mock 等实现可互换
#[async_trait]
pub trait AgentConfirmationTaskRepository: Send + Sync {
    /// 创建一条新的确认任务
    async fn create(&self, task: AgentConfirmationTask) -> PetResult<AgentConfirmationTask>;

    /// 按宠物读取 pending 状态的确认任务，按创建时间降序
    async fn list_pending_by_pet(&self, pet_id: Uuid) -> PetResult<Vec<AgentConfirmationTask>>;

    /// 按 ID 读取单条确认任务
    async fn get_by_id(&self, id: Uuid) -> PetResult<AgentConfirmationTask>;

    /// 更新任务状态（answered、dismissed 等）
    /// 当 status 为 answered 时可携带 answer_payload 和 resolved_event_id
    async fn update_status(
        &self,
        id: Uuid,
        status: &str,
        answer_payload: Option<serde_json::Value>,
        resolved_event_id: Option<Uuid>,
    ) -> PetResult<()>;
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::DateTime;
    use maohuoban_pet_domain::pet::{ConfirmationTaskKind, ConfirmationTaskStatus};

    struct MockAgentConfirmationTaskRepository;

    #[async_trait]
    impl AgentConfirmationTaskRepository for MockAgentConfirmationTaskRepository {
        async fn create(&self, task: AgentConfirmationTask) -> PetResult<AgentConfirmationTask> {
            Ok(task)
        }

        async fn list_pending_by_pet(
            &self,
            _pet_id: Uuid,
        ) -> PetResult<Vec<AgentConfirmationTask>> {
            Ok(Vec::new())
        }

        async fn get_by_id(&self, id: Uuid) -> PetResult<AgentConfirmationTask> {
            Ok(AgentConfirmationTask {
                id,
                pet_id: Uuid::nil(),
                task_kind: ConfirmationTaskKind::DietChangeConfirmation,
                question_text: "最近是否更换了主粮？".to_string(),
                candidate_payload: None,
                source_hint_id: None,
                source_ref_type: None,
                source_ref_id: None,
                status: ConfirmationTaskStatus::Pending,
                answer_payload: None,
                resolved_event_id: None,
                created_at: DateTime::from_timestamp_nanos(0),
                resolved_at: None,
            })
        }

        async fn update_status(
            &self,
            _id: Uuid,
            _status: &str,
            _answer_payload: Option<serde_json::Value>,
            _resolved_event_id: Option<Uuid>,
        ) -> PetResult<()> {
            Ok(())
        }
    }

    fn block_on<F: std::future::Future>(future: F) -> F::Output {
        tokio::runtime::Runtime::new().unwrap().block_on(future)
    }

    #[test]
    fn mock_repository_create_roundtrip() {
        let repo = MockAgentConfirmationTaskRepository;
        let task = AgentConfirmationTask {
            id: Uuid::nil(),
            pet_id: Uuid::nil(),
            task_kind: ConfirmationTaskKind::DietChangeConfirmation,
            question_text: "测试确认任务".to_string(),
            candidate_payload: None,
            source_hint_id: None,
            source_ref_type: None,
            source_ref_id: None,
            status: ConfirmationTaskStatus::Pending,
            answer_payload: None,
            resolved_event_id: None,
            created_at: DateTime::from_timestamp_nanos(0),
            resolved_at: None,
        };

        let result = block_on(repo.create(task.clone())).unwrap();
        assert_eq!(result.id, task.id);
        assert_eq!(result.task_kind, task.task_kind);
    }

    #[test]
    fn mock_repository_list_pending_returns_empty() {
        let repo = MockAgentConfirmationTaskRepository;
        let result = block_on(repo.list_pending_by_pet(Uuid::nil())).unwrap();
        assert!(result.is_empty());
    }

    #[test]
    fn mock_repository_get_by_id_returns_task() {
        let repo = MockAgentConfirmationTaskRepository;
        let id = Uuid::new_v4();
        let result = block_on(repo.get_by_id(id)).unwrap();
        assert_eq!(result.id, id);
    }

    #[test]
    fn mock_repository_update_status_succeeds() {
        let repo = MockAgentConfirmationTaskRepository;
        let result = block_on(repo.update_status(
            Uuid::nil(),
            "answered",
            Some(serde_json::json!({"confirmed": true})),
            Some(Uuid::nil()),
        ));
        assert!(result.is_ok());
    }
}
