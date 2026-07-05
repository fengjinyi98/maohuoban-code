mod album;
mod diet;
mod media;

pub use album::{
    AddPetAlbumAssetInput, CreatePetAlbumInput, PetAlbumAssetPage, PetAlbumListPage,
    PetAlbumRepository, UpdatePetAlbumInput,
};
pub use diet::{
    ConfirmPetDietCandidateInput, ConfirmPetDietCandidateResult, DietContextItem, DietRepository,
    FoodInventoryChangeHint, FoodInventoryChangeHints, FoodInventoryRepository,
    NewFoodInventoryItem, PetCurrentDietContext, PetDietConfirmationCandidate,
    PetDietConfirmationCandidates, PetRecentHealthFacts, RecentDietChangeFact, RecentFeedingFact,
    RecentHealthQuickFact, SetPetCurrentStapleInput, SetPetDietAssignmentInput,
    UpdateFoodInventoryItem,
};
pub use media::{
    BindUploadedPetMediaInput, MediaAssetDisplayMetadata, MediaCropMetadata,
    PendingPetLivePhotoUploadInput, PendingPetMediaUploadInput,
};

use async_trait::async_trait;
use chrono::{DateTime, NaiveDate, Utc};
use maohuoban_pet_domain::pet::{
    EventKind, EventVisibility, GuardianRole, GuardianType, IdentifierType, LifecycleEventKind,
    OriginKind, PetEvent, PetExternalIdentifier, PetGuardian, PetIdentityContext,
    PetLifecycleEvent, PetMediaUploadResult, PetNeuterStatus, PetProfile, PetResult, PetSex,
    PetSourceKind, PetSpecies, PetTimeline,
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
    pub microchip_number: Option<String>,
    pub arrival_date: Option<NaiveDate>,
    pub weight_grams: Option<i32>,
    pub neuter_status: PetNeuterStatus,
    pub personality_tags: Vec<String>,
    pub note: Option<String>,
    pub avatar_asset_id: Option<Uuid>,
    pub background_asset_id: Option<Uuid>,
    pub source_kind: PetSourceKind,
    pub origin_kind: OriginKind,
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

/// UpdatePetProfileResult 宠物档案更新结果
/// 核心职责：
/// - 返回更新后的宠物档案
/// - 标记本次请求是否产生持久化变更
#[derive(Debug, Clone)]
pub struct UpdatePetProfileResult {
    pub profile: PetProfile,
    pub changed: bool,
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

/// UpdatePetEvent 更新宠物事件输入
/// 核心职责：
/// - 表达通用事件详情编辑态提交内容
/// - 保留事件 ID 作为稳定详情路由
#[derive(Debug, Clone)]
pub struct UpdatePetEvent {
    pub event_id: Uuid,
    pub actor_user_id: Uuid,
    pub event_kind: EventKind,
    pub event_subkind: Option<String>,
    pub title: String,
    pub summary: Option<String>,
    pub visibility: EventVisibility,
    pub event_payload: Value,
    pub occurred_at: DateTime<Utc>,
}

/// PetWeightRecordSource 体重记录来源
/// 核心职责：
/// - 区分建档初始体重和用户手动新增记录
/// - 为客户端展示和审计提供稳定语义
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PetWeightRecordSource {
    ProfileInitial,
    Manual,
}

impl PetWeightRecordSource {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::ProfileInitial => "profile_initial",
            Self::Manual => "manual",
        }
    }
}

/// PetWeightRecord 宠物体重记录
/// 核心职责：
/// - 表达体重专用读模型
/// - 隔离底层事件账本和客户端体重页面
#[derive(Debug, Clone)]
pub struct PetWeightRecord {
    pub id: Uuid,
    pub pet_id: Uuid,
    pub weight_grams: i32,
    pub note: Option<String>,
    pub source: PetWeightRecordSource,
    pub occurred_at: DateTime<Utc>,
    pub record_revision: i32,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// NewPetWeightRecord 新建体重记录输入
/// 核心职责：
/// - 承载体重数值、备注和发生时间
/// - 由应用服务统一校验并映射为事件账本
#[derive(Debug, Clone)]
pub struct NewPetWeightRecord {
    pub pet_id: Uuid,
    pub actor_user_id: Uuid,
    pub weight_grams: i32,
    pub note: Option<String>,
    pub source: PetWeightRecordSource,
    pub occurred_at: DateTime<Utc>,
}

/// UpdatePetWeightRecord 更新体重记录输入
/// 核心职责：
/// - 表达体重记录编辑态提交内容
/// - 保留原记录 id 作为稳定详情路由
#[derive(Debug, Clone)]
pub struct UpdatePetWeightRecord {
    pub record_id: Uuid,
    pub actor_user_id: Uuid,
    pub weight_grams: i32,
    pub note: Option<String>,
    pub occurred_at: DateTime<Utc>,
}

/// DeletePetWeightRecord 删除体重记录输入
/// 核心职责：
/// - 表达用户删除体重记录意图
/// - 保留 actor 用于权限判断
#[derive(Debug, Clone)]
pub struct DeletePetWeightRecord {
    pub record_id: Uuid,
    pub actor_user_id: Uuid,
}

/// DeletedPetWeightRecord 删除体重记录结果
/// 核心职责：
/// - 返回被删除记录 id
/// - 为 HTTP 层提供稳定成功响应
#[derive(Debug, Clone)]
pub struct DeletedPetWeightRecord {
    pub id: Uuid,
    pub deleted: bool,
}

/// DeletePetEvent 删除宠物事件输入
/// 核心职责：
/// - 表达用户删除一条宠物事件的意图
/// - 保留 actor 用于权限判断
#[derive(Debug, Clone)]
pub struct DeletePetEvent {
    pub event_id: Uuid,
    pub actor_user_id: Uuid,
}

/// DeletedPetEvent 删除宠物事件结果
/// 核心职责：
/// - 返回被删除事件 id
/// - 为 HTTP 层提供稳定成功响应
#[derive(Debug, Clone)]
pub struct DeletedPetEvent {
    pub id: Uuid,
    pub deleted: bool,
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

/// AddPetExternalIdentifier 新增宠物外部标识输入
/// 核心职责：
/// - 为宠物绑定芯片号等外部标识
/// - 默认 self_reported 验证状态
#[derive(Debug, Clone)]
pub struct AddPetExternalIdentifier {
    pub pet_id: Uuid,
    pub actor_user_id: Uuid,
    pub identifier_type: IdentifierType,
    pub identifier_value: String,
    pub issuer: Option<String>,
    pub issued_at: Option<DateTime<Utc>>,
}

/// ReplacePetExternalIdentifier 替换宠物外部标识输入
/// 核心职责：
/// - 标记旧标识为 replaced
/// - 新增一条 active 标识记录
#[derive(Debug, Clone)]
pub struct ReplacePetExternalIdentifier {
    pub old_identifier_id: Uuid,
    pub pet_id: Uuid,
    pub actor_user_id: Uuid,
    pub new_identifier_value: String,
    pub issuer: Option<String>,
    pub issued_at: Option<DateTime<Utc>>,
}

/// AddPetGuardian 添加宠物归属关系输入
/// 核心职责：
/// - 创建宠物时同步写入初始 owner/merchant 关系
#[derive(Debug, Clone)]
pub struct AddPetGuardian {
    pub pet_id: Uuid,
    pub guardian_type: GuardianType,
    pub guardian_user_id: Option<Uuid>,
    pub guardian_merchant_id: Option<Uuid>,
    pub role: GuardianRole,
    pub granted_by_user_id: Option<Uuid>,
}

/// AbnormalSymptomEventInput 异常症状事件创建输入
/// 核心职责：
/// - 承载 handle_abnormal_symptom_event 所需的全部参数
/// - 避免函数签名超过 clippy too_many_arguments 阈值
#[derive(Debug, Clone)]
pub struct AbnormalSymptomEventInput {
    pub pet_id: Uuid,
    pub actor_user_id: Uuid,
    pub event_id: Uuid,
    pub symptom_kinds_json: String,
    pub primary_symptom: String,
    pub severity: String,
    pub started_at: DateTime<Utc>,
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

    async fn update_pet_profile(
        &self,
        input: UpdatePetProfile,
    ) -> PetResult<UpdatePetProfileResult>;

    async fn soft_delete_pet_profile(&self, input: DeletePetProfile) -> PetResult<PetProfile>;

    async fn restore_pet_profile(&self, input: RestorePetProfile) -> PetResult<PetProfile>;

    async fn upload_pending_pet_media(
        &self,
        input: PendingPetMediaUploadInput,
    ) -> PetResult<PetMediaUploadResult>;

    async fn upload_pending_pet_live_photo(
        &self,
        input: PendingPetLivePhotoUploadInput,
    ) -> PetResult<PetMediaUploadResult>;

    async fn bind_uploaded_pet_media(
        &self,
        input: BindUploadedPetMediaInput,
    ) -> PetResult<PetMediaUploadResult>;

    async fn list_media_display_metadata(
        &self,
        asset_ids: &[Uuid],
    ) -> PetResult<Vec<MediaAssetDisplayMetadata>>;

    /// 当提交异常症状事件时，原子创建 abnormal_episode + attention_hint
    /// 返回 episode_id，调用方应将其写入 event_payload
    /// 参数使用字符串而非领域枚举，避免跨 crate 序列化依赖
    async fn handle_abnormal_symptom_event(
        &self,
        input: AbnormalSymptomEventInput,
    ) -> PetResult<Uuid>;

    /// create_abnormal_symptom_event 事务级异常事件创建
    /// 核心职责：
    /// - 在同一个事务中写入 pet_events + abnormal_episodes + attention_hints
    /// - 自动将 episode_id 写入 event_payload
    /// - 返回包含 episode_id 的完整 PetEvent
    async fn create_abnormal_symptom_event(&self, input: NewPetEvent) -> PetResult<PetEvent>;

    /// update_episode_for_recovery 标记异常 episode 恢复
    /// 核心职责：
    /// - 更新 abnormal_episodes.status = recovered, recovered_at, latest_event_id
    /// - 将关联的 attention_hints 标记为 resolved
    async fn update_episode_for_recovery(
        &self,
        pet_id: Uuid,
        event_id: Uuid,
        episode_id: Option<Uuid>,
        recovered_at: chrono::DateTime<Utc>,
    ) -> PetResult<()>;

    /// load_attention_hints 从 DB 查询 active attention_hints
    /// 核心职责：
    /// - 按 pet_id 查询状态为 active 的 attention_hints
    /// - 按 priority DESC, created_at DESC 排序
    /// - 返回 JSON Value 列表，由调用方反序列化为领域类型
    async fn load_attention_hints(&self, pet_id: Uuid) -> PetResult<Vec<serde_json::Value>>;

    /// update_episode_for_followup 更新异常 episode 的观察时间线
    /// 核心职责：
    /// - 更新 abnormal_episodes.last_observed_at, latest_event_id
    /// - episode_id 为 None 时查找最新 open episode
    async fn update_episode_for_followup(
        &self,
        pet_id: Uuid,
        event_id: Uuid,
        episode_id: Option<Uuid>,
        observed_at: chrono::DateTime<Utc>,
    ) -> PetResult<()>;

    async fn create_pet_event(&self, input: NewPetEvent) -> PetResult<PetEvent>;

    async fn update_pet_event(&self, input: UpdatePetEvent) -> PetResult<PetEvent>;

    async fn create_pet_weight_record(
        &self,
        input: NewPetWeightRecord,
    ) -> PetResult<PetWeightRecord>;

    async fn list_pet_weight_records(
        &self,
        owner_user_id: Uuid,
        pet_id: Uuid,
        limit: i64,
    ) -> PetResult<Vec<PetWeightRecord>>;

    async fn load_pet_weight_record(
        &self,
        owner_user_id: Uuid,
        record_id: Uuid,
    ) -> PetResult<Option<PetWeightRecord>>;

    async fn update_pet_weight_record(
        &self,
        input: UpdatePetWeightRecord,
    ) -> PetResult<PetWeightRecord>;

    async fn delete_pet_weight_record(
        &self,
        input: DeletePetWeightRecord,
    ) -> PetResult<DeletedPetWeightRecord>;

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

    async fn delete_pet_event(&self, input: DeletePetEvent) -> PetResult<DeletedPetEvent>;

    async fn add_external_identifier(
        &self,
        input: AddPetExternalIdentifier,
    ) -> PetResult<PetExternalIdentifier>;

    async fn replace_external_identifier(
        &self,
        input: ReplacePetExternalIdentifier,
    ) -> PetResult<PetExternalIdentifier>;

    async fn list_external_identifiers(
        &self,
        pet_id: Uuid,
    ) -> PetResult<Vec<PetExternalIdentifier>>;

    async fn add_guardian(&self, input: AddPetGuardian) -> PetResult<PetGuardian>;

    async fn list_guardians(&self, pet_id: Uuid) -> PetResult<Vec<PetGuardian>>;

    /// 基于关系判断用户是否有权访问宠物（替代 find_pet_for_owner）
    async fn authorize_pet_access(
        &self,
        pet_id: Uuid,
        user_id: Uuid,
    ) -> PetResult<Option<PetProfile>>;

    async fn append_lifecycle_event(
        &self,
        pet_id: Uuid,
        event_kind: LifecycleEventKind,
        actor_user_id: Option<Uuid>,
        note: Option<String>,
    ) -> PetResult<PetLifecycleEvent>;

    async fn list_lifecycle_events(&self, pet_id: Uuid) -> PetResult<Vec<PetLifecycleEvent>>;

    /// 获取 Agent 身份上下文（聚合身份、关系、标识、生命周期）
    /// user_id 用于授权校验，非 owner/guardian 不可读取
    async fn load_identity_context(
        &self,
        pet_id: Uuid,
        user_id: Uuid,
    ) -> PetResult<PetIdentityContext>;
}
