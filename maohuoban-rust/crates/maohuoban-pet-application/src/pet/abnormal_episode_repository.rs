// AbnormalEpisodeRepository 异常 Episode 仓储端口
// 核心职责：
// - 定义 abnormal_episodes 持久化操作的端口 trait
// - 支持创建、按宠物读取、按 ID 读取、更新状态

use async_trait::async_trait;
use maohuoban_pet_domain::pet::{AbnormalEpisode, PetResult};
use uuid::Uuid;

/// AbnormalEpisodeRepository 异常 Episode 仓储端口
/// 核心职责：
/// - 为 AbnormalEpisode 提供持久化抽象
/// - 让 PostgreSQL、in-memory mock 等实现可互换
#[async_trait]
pub trait AbnormalEpisodeRepository: Send + Sync {
    /// 创建异常 episode
    async fn create(&self, episode: AbnormalEpisode) -> PetResult<AbnormalEpisode>;

    /// 按宠物读取所有 episode，按创建时间降序
    async fn list_by_pet(&self, pet_id: Uuid) -> PetResult<Vec<AbnormalEpisode>>;

    /// 按 ID 读取单个 episode
    async fn get_by_id(&self, id: Uuid) -> PetResult<AbnormalEpisode>;

    /// 更新 episode 状态（恢复、关闭等）
    async fn update_status(&self, id: Uuid, status: &str) -> PetResult<()>;
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::DateTime;
    use maohuoban_pet_domain::pet::{AbnormalEpisodeStatus, Severity, SymptomKind};

    struct MockAbnormalEpisodeRepository;

    #[async_trait]
    impl AbnormalEpisodeRepository for MockAbnormalEpisodeRepository {
        async fn create(&self, episode: AbnormalEpisode) -> PetResult<AbnormalEpisode> {
            Ok(episode)
        }

        async fn list_by_pet(&self, _pet_id: Uuid) -> PetResult<Vec<AbnormalEpisode>> {
            Ok(Vec::new())
        }

        async fn get_by_id(&self, id: Uuid) -> PetResult<AbnormalEpisode> {
            Ok(AbnormalEpisode {
                id,
                pet_id: Uuid::nil(),
                status: AbnormalEpisodeStatus::Open,
                primary_symptom_kind: SymptomKind::Appetite,
                symptom_kinds: vec![],
                severity: Severity::Mild,
                started_at: DateTime::from_timestamp_nanos(0),
                last_observed_at: None,
                recovered_at: None,
                created_by_user_id: Uuid::nil(),
                created_event_id: Uuid::nil(),
                latest_event_id: None,
                created_at: DateTime::from_timestamp_nanos(0),
                updated_at: DateTime::from_timestamp_nanos(0),
            })
        }

        async fn update_status(&self, _id: Uuid, _status: &str) -> PetResult<()> {
            Ok(())
        }
    }

    fn block_on<F: std::future::Future>(future: F) -> F::Output {
        tokio::runtime::Runtime::new().unwrap().block_on(future)
    }

    #[test]
    fn mock_repository_create_roundtrip() {
        let repo = MockAbnormalEpisodeRepository;
        let episode = AbnormalEpisode {
            id: Uuid::nil(),
            pet_id: Uuid::nil(),
            status: AbnormalEpisodeStatus::Open,
            primary_symptom_kind: SymptomKind::Stool,
            symptom_kinds: vec![SymptomKind::Stool, SymptomKind::Energy],
            severity: Severity::Obvious,
            started_at: DateTime::from_timestamp_nanos(0),
            last_observed_at: None,
            recovered_at: None,
            created_by_user_id: Uuid::nil(),
            created_event_id: Uuid::nil(),
            latest_event_id: None,
            created_at: DateTime::from_timestamp_nanos(0),
            updated_at: DateTime::from_timestamp_nanos(0),
        };

        let result = block_on(repo.create(episode.clone())).unwrap();
        assert_eq!(result.id, episode.id);
    }

    #[test]
    fn mock_repository_list_by_pet_returns_empty() {
        let repo = MockAbnormalEpisodeRepository;
        let result = block_on(repo.list_by_pet(Uuid::nil())).unwrap();
        assert!(result.is_empty());
    }

    #[test]
    fn mock_repository_get_by_id_returns_episode() {
        let repo = MockAbnormalEpisodeRepository;
        let id = Uuid::new_v4();
        let result = block_on(repo.get_by_id(id)).unwrap();
        assert_eq!(result.id, id);
    }

    #[test]
    fn mock_repository_update_status_succeeds() {
        let repo = MockAbnormalEpisodeRepository;
        let result = block_on(repo.update_status(Uuid::nil(), "recovered"));
        assert!(result.is_ok());
    }
}
