use async_trait::async_trait;
use chrono::{DateTime, NaiveDate, Utc};
use maohuoban_pet_domain::pet::{
    EventKind, EventVisibility, GuardianRole, GuardianType, IdentifierType, LifecycleEventKind,
    MediaUsageKind, OriginKind, PetEvent, PetExternalIdentifier, PetGuardian, PetIdentityContext,
    PetLifecycleEvent, PetMediaUploadResult, PetNeuterStatus, PetProfile, PetResult, PetSex,
    PetSourceKind, PetSpecies, PetTimeline,
};
use serde_json::Value;
use uuid::Uuid;

/// MediaAssetDisplayMetadata 媒体展示元数据
/// 核心职责：
/// - 为首页和档案展示提供媒体尺寸
/// - 暴露后端派生出的主题色结果
#[derive(Debug, Clone, PartialEq)]
pub struct MediaAssetDisplayMetadata {
    pub asset_id: Uuid,
    pub width: Option<i32>,
    pub height: Option<i32>,
    pub theme_color_hex: Option<String>,
    pub crop_metadata: Option<MediaCropMetadata>,
    pub live_photo_still_url: Option<String>,
    pub live_photo_still_width: Option<i32>,
    pub live_photo_still_height: Option<i32>,
    pub live_photo_paired_video_url: Option<String>,
    pub live_photo_paired_video_width: Option<i32>,
    pub live_photo_paired_video_height: Option<i32>,
    pub live_photo_paired_video_duration_ms: Option<i32>,
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

/// PendingPetLivePhotoUploadInput 未绑定宠物 Live Photo 上传输入
/// 核心职责：
/// - 同时承载 Live Photo 静态图和配对视频
/// - 保持组合媒体上传与单文件上传端口分离
#[derive(Debug, Clone)]
pub struct PendingPetLivePhotoUploadInput {
    pub owner_user_id: Uuid,
    pub still_file_name: String,
    pub still_mime_type: String,
    pub still_content: Vec<u8>,
    pub paired_video_file_name: String,
    pub paired_video_mime_type: String,
    pub paired_video_content: Vec<u8>,
    pub source_client: Option<String>,
    pub crop_metadata: Option<MediaCropMetadata>,
}

/// MediaCropMetadata 媒体裁剪元数据
/// 核心职责：
/// - 使用归一化坐标表达客户端选择的展示裁剪区域
/// - 为 Live Photo 保留原始组件资源时提供构图契约
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct MediaCropMetadata {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
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
    async fn load_identity_context(&self, pet_id: Uuid) -> PetResult<PetIdentityContext>;
}
