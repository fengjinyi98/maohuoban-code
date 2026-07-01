use std::sync::Arc;

use async_trait::async_trait;
use maohuoban_ai_application::ai::ports::AuthorizedPetCatalog;
use maohuoban_ai_domain::ai::{AiError, AiPetCandidate, AiResult};
use maohuoban_pet_application::pet::PetService;
use uuid::Uuid;

/// `PetServiceAuthorizedPetCatalog` AI 授权宠物候选适配器
/// 核心职责：
/// - 通过现有 `PetService` 读取当前 actor 可访问宠物档案
/// - 裁剪为 AI 宠物解析所需的最小候选摘要
#[derive(Clone)]
pub(crate) struct PetServiceAuthorizedPetCatalog {
    pet: Arc<PetService>,
}

impl PetServiceAuthorizedPetCatalog {
    /// new 构造宠物服务候选适配器
    #[must_use]
    pub(crate) fn new(pet: Arc<PetService>) -> Self {
        Self { pet }
    }
}

#[async_trait]
impl AuthorizedPetCatalog for PetServiceAuthorizedPetCatalog {
    async fn list_authorized_candidates(
        &self,
        actor_user_id: Uuid,
    ) -> AiResult<Vec<AiPetCandidate>> {
        let profiles = self
            .pet
            .list_pet_profiles(actor_user_id)
            .await
            .map_err(|error| AiError::Infrastructure(error.to_string()))?;

        Ok(profiles
            .into_iter()
            .map(|profile| AiPetCandidate {
                pet_id: profile.id,
                name: profile.name,
                avatar_url: profile.avatar_asset_id.map(media_asset_url),
                species: profile.species.as_str().to_owned(),
                profile_number: profile.profile_number,
            })
            .collect())
    }
}

/// `media_asset_url` 构造媒体资产内容 URL
/// 核心职责：
/// - 对齐首页和宠物档案已有媒体 URL 契约
/// - 为 AI 历史快照提供可直接展示的相对地址
fn media_asset_url(asset_id: Uuid) -> String {
    format!("/api/v1/media/assets/{asset_id}/content")
}
