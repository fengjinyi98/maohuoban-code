use std::sync::Arc;

use maohuoban_pet_domain::pet::{PetError, PetEvent, PetProfile, PetResult, PetTimeline};
use uuid::Uuid;

use super::{NewPetEvent, NewPetProfile, PetRepository};

/// PetService 宠物应用服务
/// 核心职责：
/// - 编排宠物档案创建、事件追加和时间线读取
/// - 将输入校验和所有权检查保持在应用层
pub struct PetService {
    repository: Arc<dyn PetRepository>,
}

impl PetService {
    #[must_use]
    pub fn new(repository: Arc<dyn PetRepository>) -> Self {
        Self { repository }
    }

    pub async fn create_pet_profile(&self, input: NewPetProfile) -> PetResult<PetProfile> {
        validate_text("宠物名称", &input.name)?;
        self.repository.create_pet_profile(input).await
    }

    pub async fn create_pet_event(&self, input: NewPetEvent) -> PetResult<PetEvent> {
        validate_text("事件标题", &input.title)?;
        if self
            .repository
            .find_pet_for_owner(input.pet_id, input.actor_user_id)
            .await?
            .is_none()
        {
            return Err(PetError::PetNotFound);
        }
        self.repository.create_pet_event(input).await
    }

    pub async fn load_pet_timeline(
        &self,
        owner_user_id: Uuid,
        pet_id: Uuid,
    ) -> PetResult<PetTimeline> {
        if self
            .repository
            .find_pet_for_owner(pet_id, owner_user_id)
            .await?
            .is_none()
        {
            return Err(PetError::PetNotFound);
        }
        self.repository
            .load_pet_timeline(owner_user_id, pet_id, 50)
            .await
    }
}

/// validate_text 校验用户输入文案
/// 核心职责：
/// - 拒绝空白关键字段
/// - 输出可映射的领域错误
fn validate_text(label: &str, value: &str) -> PetResult<()> {
    if value.trim().is_empty() {
        return Err(PetError::InvalidInput(format!("{label}不能为空")));
    }
    Ok(())
}
