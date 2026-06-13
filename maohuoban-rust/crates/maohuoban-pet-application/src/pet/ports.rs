use async_trait::async_trait;
use chrono::{DateTime, NaiveDate, Utc};
use maohuoban_pet_domain::pet::{
    EventKind, EventVisibility, PetEvent, PetProfile, PetResult, PetSex, PetSourceKind, PetSpecies,
    PetTimeline,
};
use serde_json::Value;
use uuid::Uuid;

/// NewPetProfile 新建宠物档案输入
/// 核心职责：
/// - 汇总创建宠物档案所需字段
/// - 保持 HTTP DTO 与仓储写入解耦
#[derive(Debug, Clone)]
pub struct NewPetProfile {
    pub owner_user_id: Uuid,
    pub name: String,
    pub species: PetSpecies,
    pub breed: Option<String>,
    pub sex: PetSex,
    pub birthday: Option<NaiveDate>,
    pub source_kind: PetSourceKind,
}

/// NewPetEvent 新建宠物事件输入
/// 核心职责：
/// - 汇总追加事件所需字段
/// - 支持健康、日常、交易和商家事件共用写入路径
#[derive(Debug, Clone)]
pub struct NewPetEvent {
    pub pet_id: Uuid,
    pub actor_user_id: Uuid,
    pub event_kind: EventKind,
    pub event_subkind: Option<String>,
    pub title: String,
    pub summary: Option<String>,
    pub visibility: EventVisibility,
    pub event_payload: Value,
    pub occurred_at: DateTime<Utc>,
}

/// TradePetImportInput 交易宠物导入输入
/// 核心职责：
/// - 汇总交易完成后创建宠物档案所需字段
/// - 记录交易来源证据并进入宠物事件账本
#[derive(Debug, Clone)]
pub struct TradePetImportInput {
    pub owner_user_id: Uuid,
    pub name: String,
    pub species: PetSpecies,
    pub breed: Option<String>,
    pub sex: PetSex,
    pub birthday: Option<NaiveDate>,
    pub seller_name: String,
    pub trade_reference: Option<String>,
    pub summary: Option<String>,
    pub occurred_at: DateTime<Utc>,
}

/// TradePetImport 交易宠物导入结果
/// 核心职责：
/// - 返回新建宠物档案
/// - 返回同步追加的交易事件
#[derive(Debug, Clone)]
pub struct TradePetImport {
    pub pet: PetProfile,
    pub event: PetEvent,
}

/// PetRepository 宠物仓储端口
/// 核心职责：
/// - 持久化宠物档案和宠物事件
/// - 为首页、宠物详情和商家工作台提供时间线读取能力
#[async_trait]
pub trait PetRepository: Send + Sync {
    async fn create_pet_profile(&self, input: NewPetProfile) -> PetResult<PetProfile>;

    async fn find_pet_for_owner(
        &self,
        pet_id: Uuid,
        owner_user_id: Uuid,
    ) -> PetResult<Option<PetProfile>>;

    async fn list_pet_profiles_for_owner(&self, owner_user_id: Uuid) -> PetResult<Vec<PetProfile>>;

    async fn create_pet_event(&self, input: NewPetEvent) -> PetResult<PetEvent>;

    async fn import_trade_pet(&self, input: TradePetImportInput) -> PetResult<TradePetImport>;

    async fn load_pet_timeline(
        &self,
        owner_user_id: Uuid,
        pet_id: Uuid,
        limit: i64,
    ) -> PetResult<PetTimeline>;

    async fn load_pet_event_detail(
        &self,
        owner_user_id: Uuid,
        event_id: Uuid,
    ) -> PetResult<Option<PetEvent>>;
}
