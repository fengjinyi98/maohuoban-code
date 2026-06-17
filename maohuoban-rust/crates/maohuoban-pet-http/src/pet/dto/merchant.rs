use chrono::NaiveDate;
use maohuoban_pet_application::pet::{MerchantAvailableStatusPublication, MerchantLitterDetail};
use maohuoban_pet_domain::pet::{
    LitterStatus, ManagedPetStatus, PetProfile, PetRelationship, PetSpecies,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::{PetEventData, PetProfileData};

/// MerchantPetsQuery 商家宠物筛选查询
/// 核心职责：
/// - 接收商家宠物列表状态筛选
/// - 将 URL query 限定为领域层稳定状态枚举
#[derive(Debug, Deserialize)]
pub(crate) struct MerchantPetsQuery {
    pub(crate) status: ManagedPetStatus,
}

/// MerchantPetsData 商家宠物列表响应
/// 核心职责：
/// - 返回指定商家和状态下的在管宠物
/// - 支撑首页商家状态看板目标页
#[derive(Debug, Serialize)]
pub(crate) struct MerchantPetsData {
    pub(crate) merchant_id: Uuid,
    pub(crate) status: ManagedPetStatus,
    pub(crate) pets: Vec<PetProfileData>,
}

impl MerchantPetsData {
    pub(crate) fn new(merchant_id: Uuid, status: ManagedPetStatus, pets: Vec<PetProfile>) -> Self {
        Self {
            merchant_id,
            status,
            pets: pets.into_iter().map(PetProfileData::from).collect(),
        }
    }
}

/// MerchantAvailableStatusData 商家可售状态发布响应
/// 核心职责：
/// - 返回更新后的在管宠物状态
/// - 返回同步写入的买家可见事件
#[derive(Debug, Serialize)]
pub(crate) struct MerchantAvailableStatusData {
    pet: PetProfileData,
    event: PetEventData,
}

impl From<MerchantAvailableStatusPublication> for MerchantAvailableStatusData {
    fn from(publication: MerchantAvailableStatusPublication) -> Self {
        Self {
            pet: PetProfileData::from(publication.pet),
            event: PetEventData::from(publication.event),
        }
    }
}

/// MerchantLitterDetailData 商家窝次详情响应
/// 核心职责：
/// - 返回窝次基础信息、父母、同窝幼宠和追溯事件
/// - 隔离应用读模型和 HTTP JSON 结构
#[derive(Debug, Serialize)]
pub(crate) struct MerchantLitterDetailData {
    id: Uuid,
    merchant_id: Uuid,
    name: String,
    species: PetSpecies,
    born_at: NaiveDate,
    born_count: i32,
    alive_count: i32,
    available_count: u32,
    status: LitterStatus,
    sire_pet: Option<PetProfileData>,
    dam_pet: Option<PetProfileData>,
    children: Vec<PetProfileData>,
    relationships: Vec<PetRelationshipData>,
    recent_events: Vec<PetEventData>,
}

impl From<MerchantLitterDetail> for MerchantLitterDetailData {
    fn from(detail: MerchantLitterDetail) -> Self {
        Self {
            id: detail.litter.id,
            merchant_id: detail.litter.merchant_id,
            name: detail.litter.name,
            species: detail.litter.species,
            born_at: detail.litter.born_at,
            born_count: detail.litter.born_count,
            alive_count: detail.litter.alive_count,
            available_count: detail.available_count,
            status: detail.litter.status,
            sire_pet: detail.sire_pet.map(PetProfileData::from),
            dam_pet: detail.dam_pet.map(PetProfileData::from),
            children: detail
                .children
                .into_iter()
                .map(PetProfileData::from)
                .collect(),
            relationships: detail
                .relationships
                .into_iter()
                .map(PetRelationshipData::from)
                .collect(),
            recent_events: detail
                .recent_events
                .into_iter()
                .map(PetEventData::from)
                .collect(),
        }
    }
}

/// PetRelationshipData 宠物关系响应数据
/// 核心职责：
/// - 返回商家追溯关系边字段
/// - 保持关系详情与领域模型序列化一致
#[derive(Debug, Serialize)]
pub(crate) struct PetRelationshipData {
    #[serde(flatten)]
    relationship: PetRelationship,
}

impl From<PetRelationship> for PetRelationshipData {
    fn from(relationship: PetRelationship) -> Self {
        Self { relationship }
    }
}
