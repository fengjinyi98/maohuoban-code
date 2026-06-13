use chrono::{DateTime, NaiveDate, Utc};
use maohuoban_pet_application::pet::{NewMerchantPetProfile, NewPetEvent, NewPetProfile};
use maohuoban_pet_domain::pet::{
    EventKind, EventVisibility, ManagedPetStatus, PetEvent, PetProfile, PetSex, PetSourceKind,
    PetSpecies, PetTimeline,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use uuid::Uuid;

/// CreatePetProfileRequest 创建宠物档案请求
/// 核心职责：
/// - 接收普通用户创建宠物所需字段
/// - 将 HTTP 输入转换为应用层命令
#[derive(Debug, Deserialize)]
pub(super) struct CreatePetProfileRequest {
    name: String,
    species: PetSpecies,
    breed: Option<String>,
    sex: Option<PetSex>,
    birthday: Option<NaiveDate>,
}

impl CreatePetProfileRequest {
    pub(super) fn into_new_pet_profile(self, owner_user_id: Uuid) -> NewPetProfile {
        NewPetProfile {
            owner_user_id,
            name: self.name,
            species: self.species,
            breed: self.breed,
            sex: self.sex.unwrap_or(PetSex::Unknown),
            birthday: self.birthday,
            source_kind: PetSourceKind::UserCreated,
        }
    }
}

/// CreateMerchantPetRequest 新增商家在管宠物请求
/// 核心职责：
/// - 接收商家新增宠物所需字段
/// - 固定商家手动新增宠物的来源类型
#[derive(Debug, Deserialize)]
pub(super) struct CreateMerchantPetRequest {
    name: String,
    species: PetSpecies,
    breed: Option<String>,
    sex: Option<PetSex>,
    birthday: Option<NaiveDate>,
    managed_status: Option<ManagedPetStatus>,
}

impl CreateMerchantPetRequest {
    pub(super) fn into_new_merchant_pet(self, merchant_id: Uuid) -> NewMerchantPetProfile {
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

/// CreatePetEventRequest 创建宠物事件请求
/// 核心职责：
/// - 接收时间线事件基础字段
/// - 支持健康、日常、交易和商家事件共用结构
#[derive(Debug, Deserialize)]
pub(super) struct CreatePetEventRequest {
    event_kind: EventKind,
    event_subkind: Option<String>,
    title: String,
    summary: Option<String>,
    visibility: Option<EventVisibility>,
    event_payload: Option<Value>,
    occurred_at: DateTime<Utc>,
}

impl CreatePetEventRequest {
    pub(super) fn into_new_pet_event(self, pet_id: Uuid, actor_user_id: Uuid) -> NewPetEvent {
        NewPetEvent {
            pet_id,
            actor_user_id,
            event_kind: self.event_kind,
            event_subkind: self.event_subkind,
            title: self.title,
            summary: self.summary,
            visibility: self.visibility.unwrap_or(EventVisibility::Private),
            event_payload: self.event_payload.unwrap_or_else(|| serde_json::json!({})),
            occurred_at: self.occurred_at,
        }
    }
}

/// PetProfileData 宠物档案响应数据
/// 核心职责：
/// - 返回客户端展示和后续记录所需宠物字段
/// - 隔离领域模型和 HTTP JSON 结构
#[derive(Debug, Serialize)]
pub(super) struct PetProfileData {
    #[serde(flatten)]
    profile: PetProfile,
}

impl From<PetProfile> for PetProfileData {
    fn from(profile: PetProfile) -> Self {
        Self { profile }
    }
}

/// PetEventData 宠物事件响应数据
/// 核心职责：
/// - 返回追加事件后的稳定字段
/// - 为首页和详情页刷新时间线提供记录版本
#[derive(Debug, Serialize)]
pub(super) struct PetEventData {
    #[serde(flatten)]
    event: PetEvent,
}

impl From<PetEvent> for PetEventData {
    fn from(event: PetEvent) -> Self {
        Self { event }
    }
}

/// PetTimelineData 宠物时间线响应数据
/// 核心职责：
/// - 返回单只宠物最近事件列表
/// - 支持首页最近时间线和宠物详情页共用
#[derive(Debug, Serialize)]
pub(super) struct PetTimelineData {
    #[serde(flatten)]
    timeline: PetTimeline,
}

impl From<PetTimeline> for PetTimelineData {
    fn from(timeline: PetTimeline) -> Self {
        Self { timeline }
    }
}

/// MerchantPetsQuery 商家宠物筛选查询
/// 核心职责：
/// - 接收商家宠物列表状态筛选
/// - 将 URL query 限定为领域层稳定状态枚举
#[derive(Debug, Deserialize)]
pub(super) struct MerchantPetsQuery {
    pub(super) status: ManagedPetStatus,
}

/// MerchantPetsData 商家宠物列表响应
/// 核心职责：
/// - 返回指定商家和状态下的在管宠物
/// - 支撑首页商家状态看板目标页
#[derive(Debug, Serialize)]
pub(super) struct MerchantPetsData {
    pub(super) merchant_id: Uuid,
    pub(super) status: ManagedPetStatus,
    pub(super) pets: Vec<PetProfileData>,
}

impl MerchantPetsData {
    pub(super) fn new(merchant_id: Uuid, status: ManagedPetStatus, pets: Vec<PetProfile>) -> Self {
        Self {
            merchant_id,
            status,
            pets: pets.into_iter().map(PetProfileData::from).collect(),
        }
    }
}
