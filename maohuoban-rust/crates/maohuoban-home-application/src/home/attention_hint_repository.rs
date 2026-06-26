// AttentionHintRepository 首页轻提示仓储端口
// 核心职责：
// - 定义 attention_hints 持久化操作的端口 trait
// - 支持创建、按宠物读取 active hints、resolve、dismiss

use async_trait::async_trait;
use maohuoban_home_domain::home::AttentionHint;
use uuid::Uuid;

use super::HomeResult;

/// AttentionHintRepository 轻提示仓储端口
/// 核心职责：
/// - 为 AttentionHint 提供持久化抽象
/// - 让 PostgreSQL、in-memory mock 等实现可互换
#[async_trait]
pub trait AttentionHintRepository: Send + Sync {
    /// 创建一条新轻提示
    async fn create(&self, hint: AttentionHint) -> HomeResult<AttentionHint>;

    /// 按宠物读取 active 轻提示，按优先级降序、创建时间降序排列
    async fn list_active_by_pet(&self, pet_id: Uuid) -> HomeResult<Vec<AttentionHint>>;

    /// 按 ID resolve 一条轻提示（标记为 resolved）
    async fn resolve(&self, id: Uuid) -> HomeResult<()>;

    /// 按 ID dismiss 一条轻提示（标记为 dismissed）
    async fn dismiss(&self, id: Uuid) -> HomeResult<()>;
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::DateTime;
    use maohuoban_home_domain::home::{
        AttentionHintCreator, AttentionHintKind, AttentionHintRoute, AttentionHintRouteKind,
        AttentionHintStatus, AttentionHintTone,
    };

    struct MockAttentionHintRepository;

    #[async_trait]
    impl AttentionHintRepository for MockAttentionHintRepository {
        async fn create(&self, hint: AttentionHint) -> HomeResult<AttentionHint> {
            Ok(hint)
        }

        async fn list_active_by_pet(&self, _pet_id: Uuid) -> HomeResult<Vec<AttentionHint>> {
            Ok(Vec::new())
        }

        async fn resolve(&self, _id: Uuid) -> HomeResult<()> {
            Ok(())
        }

        async fn dismiss(&self, _id: Uuid) -> HomeResult<()> {
            Ok(())
        }
    }

    fn block_on<F: std::future::Future>(future: F) -> F::Output {
        tokio::runtime::Runtime::new().unwrap().block_on(future)
    }

    #[test]
    fn mock_repository_create_roundtrip() {
        let repo = MockAttentionHintRepository;
        let hint = AttentionHint {
            id: Uuid::nil(),
            pet_id: Uuid::nil(),
            kind: AttentionHintKind::OpenAbnormalEpisode,
            title: "测试提示".to_string(),
            subtitle: "用于测试".to_string(),
            icon: "test.icon".to_string(),
            tone: AttentionHintTone::Info,
            priority: 5,
            status: AttentionHintStatus::Active,
            source_ref_type: Some("abnormal_episode".to_string()),
            source_ref_id: Some(Uuid::nil()),
            route: AttentionHintRoute {
                kind: AttentionHintRouteKind::AbnormalDetail,
                payload: None,
            },
            display_from: None,
            display_until: None,
            created_by: AttentionHintCreator::System,
            created_at: DateTime::from_timestamp_nanos(0),
            updated_at: DateTime::from_timestamp_nanos(0),
            resolved_at: None,
        };

        let result = block_on(repo.create(hint.clone())).unwrap();
        assert_eq!(result.id, hint.id);
        assert_eq!(result.kind, hint.kind);
        assert_eq!(result.title, hint.title);
    }

    #[test]
    fn mock_repository_list_active_returns_empty() {
        let repo = MockAttentionHintRepository;
        let result = block_on(repo.list_active_by_pet(Uuid::nil())).unwrap();
        assert!(result.is_empty());
    }

    #[test]
    fn mock_repository_resolve_succeeds() {
        let repo = MockAttentionHintRepository;
        let result = block_on(repo.resolve(Uuid::nil()));
        assert!(result.is_ok());
    }

    #[test]
    fn mock_repository_dismiss_succeeds() {
        let repo = MockAttentionHintRepository;
        let result = block_on(repo.dismiss(Uuid::nil()));
        assert!(result.is_ok());
    }
}
