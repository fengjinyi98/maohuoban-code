use async_trait::async_trait;
use chrono::NaiveDate;
use maohuoban_pet_domain::pet::{
    ManagedPetStatus, MerchantProfile, MerchantStatusCount, PetEvent, PetProfile, PetRelationship,
    PetResult,
};
use uuid::Uuid;

/// MerchantDashboardSummary 商家工作台应用读模型
/// 核心职责：
/// - 汇总认证商家首页需要的多宠、窝次、关系和事件数据
/// - 保持首页聚合层不直接依赖数据库查询细节
#[derive(Debug, Clone)]
pub struct MerchantDashboardSummary {
    pub merchant: MerchantProfile,
    pub status_counts: Vec<MerchantStatusCount>,
    pub litters: Vec<MerchantLitterSummary>,
    pub relationships: Vec<PetRelationship>,
    pub recent_events: Vec<PetEvent>,
}

/// MerchantLitterSummary 商家窝次应用摘要
/// 核心职责：
/// - 承载窝次父母、出生日期和可售数量
/// - 为首页和后续窝次详情提供稳定入口数据
#[derive(Debug, Clone)]
pub struct MerchantLitterSummary {
    pub id: Uuid,
    pub name: String,
    pub sire_name: Option<String>,
    pub dam_name: Option<String>,
    pub born_at: NaiveDate,
    pub born_count: i32,
    pub alive_count: i32,
    pub available_count: u32,
}

/// MerchantRepository 商家追溯读取端口
/// 核心职责：
/// - 读取认证商家、在管宠物状态、窝次和关系
/// - 为首页工作台和后续商家模块提供可替换数据源
#[async_trait]
pub trait MerchantRepository: Send + Sync {
    async fn find_verified_merchant_for_owner(
        &self,
        owner_user_id: Uuid,
    ) -> PetResult<Option<MerchantProfile>>;

    async fn load_merchant_status_counts(
        &self,
        merchant_id: Uuid,
    ) -> PetResult<Vec<MerchantStatusCount>>;

    async fn list_merchant_litter_summaries(
        &self,
        merchant_id: Uuid,
        limit: i64,
    ) -> PetResult<Vec<MerchantLitterSummary>>;

    async fn list_merchant_relationships(
        &self,
        merchant_id: Uuid,
        limit: i64,
    ) -> PetResult<Vec<PetRelationship>>;

    async fn load_merchant_recent_events(
        &self,
        merchant_id: Uuid,
        limit: i64,
    ) -> PetResult<Vec<PetEvent>>;

    async fn list_merchant_pets(
        &self,
        merchant_id: Uuid,
        status: ManagedPetStatus,
        limit: i64,
    ) -> PetResult<Vec<PetProfile>>;
}
