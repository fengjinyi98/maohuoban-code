use async_trait::async_trait;
use chrono::{DateTime, NaiveDate, Utc};
use maohuoban_pet_domain::pet::{
    EventKind, EventVisibility, MediaUsageKind, PetEvent, PetMediaUploadResult, PetNeuterStatus,
    PetProfile, PetResult, PetSex, PetSourceKind, PetSpecies, PetTimeline,
};
use serde_json::Value;
use uuid::Uuid;

/// MediaAssetDisplayMetadata 媒体展示元数据
/// 核心职责：
/// - 为首页和档案展示提供媒体尺寸
/// - 暴露后端派生出的主题色结果
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MediaAssetDisplayMetadata {
    pub asset_id: Uuid,
    pub width: Option<i32>,
    pub height: Option<i32>,
    pub theme_color_hex: Option<String>,
}

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
    pub microchip_number: Option<String>,
    pub arrival_date: Option<NaiveDate>,
    pub weight_grams: Option<i32>,
    pub neuter_status: PetNeuterStatus,
    pub personality_tags: Vec<String>,
    pub note: Option<String>,
    pub avatar_asset_id: Option<Uuid>,
    pub background_asset_id: Option<Uuid>,
    pub source_kind: PetSourceKind,
}

/// UpdatePetProfile 宠物档案更新输入
/// 核心职责：
/// - 表达用户可编辑档案字段
/// - 保持不可编辑字段由应用服务校验
#[derive(Debug, Clone, Default)]
pub struct UpdatePetProfile {
    pub pet_id: Uuid,
    pub owner_user_id: Uuid,
    pub name: Option<String>,
    pub species: Option<PetSpecies>,
    pub breed: Option<String>,
    pub sex: Option<PetSex>,
    pub birthday: Option<NaiveDate>,
    pub microchip_number: Option<String>,
    pub arrival_date: Option<NaiveDate>,
    pub weight_grams: Option<i32>,
    pub neuter_status: Option<PetNeuterStatus>,
    pub personality_tags: Option<Vec<String>>,
    pub note: Option<String>,
}

/// DeletePetProfile 宠物档案删除输入
/// 核心职责：
/// - 表达软删除请求
/// - 保留恢复窗口和审计所需字段
#[derive(Debug, Clone)]
pub struct DeletePetProfile {
    pub pet_id: Uuid,
    pub owner_user_id: Uuid,
    pub reason: Option<String>,
}

/// RestorePetProfile 恢复宠物档案输入
/// 核心职责：
/// - 表达恢复软删除宠物档案请求
/// - 保持恢复权限由当前用户和宠物归属共同约束
#[derive(Debug, Clone)]
pub struct RestorePetProfile {
    pub pet_id: Uuid,
    pub owner_user_id: Uuid,
}

/// PendingPetMediaUploadInput 未绑定宠物媒体上传输入
/// 核心职责：
/// - 支持建档前先上传媒体资产
/// - 保持媒体资产归属和业务绑定分步完成
#[derive(Debug, Clone)]
pub struct PendingPetMediaUploadInput {
    pub owner_user_id: Uuid,
    pub usage_kind: MediaUsageKind,
    pub file_name: String,
    pub mime_type: String,
    pub content: Vec<u8>,
    pub source_client: Option<String>,
}

/// BindUploadedPetMediaInput 绑定已上传宠物媒体输入
/// 核心职责：
/// - 将 pending 媒体资产绑定到指定宠物
/// - 支持创建宠物和编辑宠物复用同一绑定能力
#[derive(Debug, Clone)]
pub struct BindUploadedPetMediaInput {
    pub pet_id: Uuid,
    pub owner_user_id: Uuid,
    pub asset_id: Uuid,
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

    async fn update_pet_profile(&self, input: UpdatePetProfile) -> PetResult<PetProfile>;

    async fn soft_delete_pet_profile(&self, input: DeletePetProfile) -> PetResult<PetProfile>;

    async fn restore_pet_profile(&self, input: RestorePetProfile) -> PetResult<PetProfile>;

    async fn upload_pending_pet_media(
        &self,
        input: PendingPetMediaUploadInput,
    ) -> PetResult<PetMediaUploadResult>;

    async fn bind_uploaded_pet_media(
        &self,
        input: BindUploadedPetMediaInput,
    ) -> PetResult<PetMediaUploadResult>;

    async fn list_media_display_metadata(
        &self,
        asset_ids: &[Uuid],
    ) -> PetResult<Vec<MediaAssetDisplayMetadata>>;

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
