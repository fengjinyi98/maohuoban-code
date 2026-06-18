use chrono::NaiveDate;
use maohuoban_pet_application::pet::{DeletePetProfile, NewPetProfile, UpdatePetProfile};
use maohuoban_pet_domain::pet::{PetNeuterStatus, PetSex, PetSourceKind, PetSpecies};
use serde::Deserialize;
use uuid::Uuid;

/// CreatePetProfileRequest 创建宠物档案请求
/// 核心职责：
/// - 接收普通用户创建宠物所需字段
/// - 将 HTTP 输入转换为应用层命令
#[derive(Debug, Deserialize)]
pub(crate) struct CreatePetProfileRequest {
    name: String,
    species: PetSpecies,
    breed: Option<String>,
    sex: Option<PetSex>,
    birthday: Option<NaiveDate>,
    microchip_number: Option<String>,
    arrival_date: Option<NaiveDate>,
    weight_grams: Option<i32>,
    neuter_status: Option<PetNeuterStatus>,
    personality_tags: Option<Vec<String>>,
    note: Option<String>,
    avatar_asset_id: Option<Uuid>,
    background_asset_id: Option<Uuid>,
}

impl CreatePetProfileRequest {
    pub(crate) fn into_new_pet_profile(self, owner_user_id: Uuid) -> NewPetProfile {
        NewPetProfile {
            owner_user_id,
            name: self.name,
            species: self.species,
            breed: self.breed,
            sex: self.sex.unwrap_or(PetSex::Unknown),
            birthday: self.birthday,
            microchip_number: self.microchip_number,
            arrival_date: self.arrival_date,
            weight_grams: self.weight_grams,
            neuter_status: self.neuter_status.unwrap_or(PetNeuterStatus::Unknown),
            personality_tags: self.personality_tags.unwrap_or_default(),
            note: self.note,
            avatar_asset_id: self.avatar_asset_id,
            background_asset_id: self.background_asset_id,
            source_kind: PetSourceKind::UserCreated,
        }
    }
}

/// UpdatePetProfileRequest 更新宠物档案请求
/// 核心职责：
/// - 接收用户可编辑字段
/// - 转换为应用层部分更新命令
#[derive(Debug, Deserialize)]
pub(crate) struct UpdatePetProfileRequest {
    name: Option<String>,
    species: Option<PetSpecies>,
    breed: Option<String>,
    sex: Option<PetSex>,
    birthday: Option<NaiveDate>,
    microchip_number: Option<String>,
    arrival_date: Option<NaiveDate>,
    weight_grams: Option<i32>,
    neuter_status: Option<PetNeuterStatus>,
    personality_tags: Option<Vec<String>>,
    note: Option<String>,
}

impl UpdatePetProfileRequest {
    pub(crate) fn into_input(self, pet_id: Uuid, owner_user_id: Uuid) -> UpdatePetProfile {
        UpdatePetProfile {
            pet_id,
            owner_user_id,
            name: self.name,
            species: self.species,
            breed: self.breed,
            sex: self.sex,
            birthday: self.birthday,
            microchip_number: self.microchip_number,
            arrival_date: self.arrival_date,
            weight_grams: self.weight_grams,
            neuter_status: self.neuter_status,
            personality_tags: self.personality_tags,
            note: self.note,
        }
    }
}

/// DeletePetProfileRequest 删除宠物档案请求
/// 核心职责：
/// - 接收用户删除原因
/// - 转换为软删除命令
#[derive(Debug, Deserialize)]
pub(crate) struct DeletePetProfileRequest {
    reason: Option<String>,
}

impl DeletePetProfileRequest {
    pub(crate) fn into_input(self, pet_id: Uuid, owner_user_id: Uuid) -> DeletePetProfile {
        DeletePetProfile {
            pet_id,
            owner_user_id,
            reason: self.reason,
        }
    }
}
