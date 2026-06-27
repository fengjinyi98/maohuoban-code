use std::sync::Arc;

use async_trait::async_trait;
use maohuoban_ai_domain::ai::{AiError, AiPetCandidate, AiResult};
use uuid::Uuid;

/// AuthorizedPetCatalog 授权宠物候选端口
/// 核心职责：
/// - 返回当前用户有权限宠物的最小摘要
/// - 字段严格裁剪，不携带饮食、异常、事件等强事实
#[async_trait]
pub trait AuthorizedPetCatalog: Send + Sync {
    /// list_authorized_candidates 返回当前 actor 授权宠物候选
    async fn list_authorized_candidates(
        &self,
        actor_user_id: Uuid,
    ) -> AiResult<Vec<AiPetCandidate>>;
}

/// EmptyPetCatalog 空宠物目录，测试占位
/// 核心职责：
/// - 返回空候选列表，用于无宠物上下文场景测试
#[derive(Clone, Copy)]
pub struct EmptyPetCatalog;

#[async_trait]
impl AuthorizedPetCatalog for EmptyPetCatalog {
    async fn list_authorized_candidates(
        &self,
        _actor_user_id: Uuid,
    ) -> AiResult<Vec<AiPetCandidate>> {
        Ok(Vec::new())
    }
}

/// InMemoryPetCatalog 内存宠物目录，测试用
/// 核心职责：
/// - 按预设候选返回，支持宠物解析 table tests
#[derive(Clone)]
pub struct InMemoryPetCatalog {
    candidates: Arc<Vec<AiPetCandidate>>,
}

impl InMemoryPetCatalog {
    /// new 构造内存目录
    #[must_use]
    pub fn new(candidates: Vec<AiPetCandidate>) -> Self {
        Self {
            candidates: Arc::new(candidates),
        }
    }
}

#[async_trait]
impl AuthorizedPetCatalog for InMemoryPetCatalog {
    async fn list_authorized_candidates(
        &self,
        _actor_user_id: Uuid,
    ) -> AiResult<Vec<AiPetCandidate>> {
        Ok((*self.candidates).clone())
    }
}

/// allow unused import guard for AiError（未来未授权场景使用）
#[allow(dead_code)]
fn _ensure_ai_error_linked() -> AiError {
    AiError::PetNotFound
}
