use chrono::{DateTime, NaiveDate, Utc};
use maohuoban_pet_application::pet::{NewMerchantPetProfile, PublishAvailableStatusInput};
use maohuoban_pet_domain::pet::{ManagedPetStatus, PetSex, PetSourceKind, PetSpecies};
use serde::Deserialize;
use uuid::Uuid;

/// CreateMerchantPetRequest 新增商家在管宠物请求
/// 核心职责：
/// - 接收商家新增宠物所需字段
/// - 固定商家手动新增宠物的来源类型
#[derive(Debug, Deserialize)]
pub(crate) struct CreateMerchantPetRequest {
    name: String,
    species: PetSpecies,
    breed: Option<String>,
    sex: Option<PetSex>,
    birthday: Option<NaiveDate>,
    managed_status: Option<ManagedPetStatus>,
}

impl CreateMerchantPetRequest {
    pub(crate) fn into_new_merchant_pet(self, merchant_id: Uuid) -> NewMerchantPetProfile {
        NewMerchantPetProfile {
            merchant_id,
            name: self.name,
            species: self.species,
            breed: self.breed,
            sex: self.sex.unwrap_or(PetSex::Unknown),
            birthday: self.birthday,
            managed_status: self.managed_status.unwrap_or(ManagedPetStatus::NeedsRecord),
            source_kind: PetSourceKind::MerchantManaged,
        }
    }
}

/// PublishAvailableStatusRequest 发布可售状态请求
/// 核心职责：
/// - 接收商家发布买家可见可售状态所需字段
/// - 将 HTTP 输入转换为应用层命令
#[derive(Debug, Deserialize)]
pub(crate) struct PublishAvailableStatusRequest {
    summary: Option<String>,
    occurred_at: DateTime<Utc>,
}

impl PublishAvailableStatusRequest {
    pub(crate) fn into_input(
        self,
        merchant_id: Uuid,
        pet_id: Uuid,
        actor_user_id: Uuid,
    ) -> PublishAvailableStatusInput {
        PublishAvailableStatusInput {
            merchant_id,
            pet_id,
            actor_user_id,
            summary: self.summary,
            occurred_at: self.occurred_at,
        }
    }
}
