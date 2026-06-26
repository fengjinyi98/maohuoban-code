use async_trait::async_trait;
use chrono::{DateTime, NaiveDate, Utc};
use maohuoban_pet_domain::pet::{
    DietAssignmentRole, EventKind, EventVisibility, FoodInventoryCategory, FoodInventoryItem,
    FoodInventoryStatus, FoodScopeType, FoodSnapshot, FoodSourceKind, GuardianRole, GuardianType,
    IdentifierType, LifecycleEventKind, MediaUsageKind, OriginKind, PetDietAssignment, PetEvent,
    PetExternalIdentifier, PetGuardian, PetIdentityContext, PetLifecycleEvent,
    PetMediaUploadResult, PetNeuterStatus, PetProfile, PetResult, PetSex, PetSourceKind,
    PetSpecies, PetTimeline,
};
use serde::{Deserialize, Serialize};
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

/// SetPetCurrentStapleInput 设为当前主粮输入
/// 核心职责：
/// - 结束旧 active 当前主粮，创建新 active 当前主粮
/// - 写入 diet_change 事件
#[derive(Debug, Clone)]
pub struct SetPetCurrentStapleInput {
    pub pet_id: Uuid,
    pub food_item_id: Uuid,
    pub created_by_user_id: Uuid,
    pub reason: Option<String>,
}

/// SetPetDietAssignmentInput 饮食配置输入
/// 核心职责：
/// - 设置尝试中、常用零食/营养品、禁用/不适合
#[derive(Debug, Clone)]
pub struct SetPetDietAssignmentInput {
    pub pet_id: Uuid,
    pub food_item_id: Uuid,
    pub role: DietAssignmentRole,
    pub created_by_user_id: Uuid,
    pub reason: Option<String>,
}

/// DietRepository 宠物饮食配置仓储端口
/// 核心职责：
/// - 持久化宠物对食品资产的消费配置关系
/// - 同一宠物同一时间只能有一个 active current_staple
#[async_trait]
pub trait DietRepository: Send + Sync {
    async fn set_current_staple(
        &self,
        input: SetPetCurrentStapleInput,
    ) -> PetResult<PetDietAssignment>;

    async fn set_assignment(
        &self,
        input: SetPetDietAssignmentInput,
    ) -> PetResult<PetDietAssignment>;

    async fn end_assignment(
        &self,
        pet_id: Uuid,
        assignment_id: Uuid,
        ended_by_user_id: Uuid,
    ) -> PetResult<PetDietAssignment>;

    async fn list_active_assignments(&self, pet_id: Uuid) -> PetResult<Vec<PetDietAssignment>>;

    async fn find_current_staple(&self, pet_id: Uuid) -> PetResult<Option<PetDietAssignment>>;

    /// 加载宠物当前饮食上下文（强事实）
    async fn load_pet_current_diet_context(&self, pet_id: Uuid)
    -> PetResult<PetCurrentDietContext>;

    /// 加载近期储物柜变化线索（弱线索）
    async fn load_food_inventory_change_hints(
        &self,
        scope_type: FoodScopeType,
        scope_id: Uuid,
        since: chrono::DateTime<chrono::Utc>,
    ) -> PetResult<FoodInventoryChangeHints>;
}

/// DietContextItem 饮食上下文单项
/// 核心职责：
/// - 表达某只宠物当前的饮食配置项
/// - 包含食品引用和角色信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DietContextItem {
    pub assignment_id: Uuid,
    pub food_item_id: Uuid,
    pub food_name: String,
    pub food_brand: Option<String>,
    pub food_category: String,
    pub role: String,
    pub status: String,
}

/// PetCurrentDietContext 宠物当前饮食上下文（强事实）
/// 核心职责：
/// - 汇总当前主粮、尝试中、常用零食/营养品
/// - 包含最近喂食事件和饮食配置变更
/// - Agent 分析的强事实来源
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PetCurrentDietContext {
    pub current_staple: Option<DietContextItem>,
    pub trying_foods: Vec<DietContextItem>,
    pub usual_treats: Vec<DietContextItem>,
    pub usual_nutritions: Vec<DietContextItem>,
    pub recent_feeding_events: Vec<RecentFeedingFact>,
    pub recent_diet_changes: Vec<RecentDietChangeFact>,
}

/// RecentFeedingFact 最近喂食事实
/// 核心职责：
/// - 携带 food_item_id 和 food_snapshot
/// - Agent 用于分析宠物实际摄入
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RecentFeedingFact {
    pub event_id: Uuid,
    pub occurred_at: chrono::DateTime<chrono::Utc>,
    pub food_item_id: Option<Uuid>,
    pub food_name: String,
    pub food_snapshot: Option<FoodSnapshot>,
}

/// RecentDietChangeFact 最近饮食配置变更事实
/// 核心职责：
/// - 暴露 diet_change 事件中的食品切换信息
/// - 让 Agent 在异常分析时优先读取强事实
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RecentDietChangeFact {
    pub event_id: Uuid,
    pub occurred_at: chrono::DateTime<chrono::Utc>,
    pub event_subkind: String,
    pub from_food_item_id: Option<Uuid>,
    pub to_food_item_id: Uuid,
    pub assignment_id: Uuid,
    pub transition_state: String,
}

/// FoodInventoryChangeHint 储物柜变化线索（弱线索）
/// 核心职责：
/// - 标记近期储物柜新增/编辑/恢复的食品
/// - 仅作为 Agent 追问线索，不能直接推断宠物吃过
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FoodInventoryChangeHint {
    pub item_id: Uuid,
    pub name: String,
    pub category: String,
    pub change_kind: String,
    pub changed_at: chrono::DateTime<chrono::Utc>,
    pub fact_strength: String,
}

/// FoodInventoryChangeHints 储物柜变化线索集合
/// 核心职责：
/// - 汇总近期储物柜变化弱线索
/// - Agent 仅在强事实不足时才参考
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FoodInventoryChangeHints {
    pub hints: Vec<FoodInventoryChangeHint>,
}

/// PetDietConfirmationCandidate 宠物饮食待确认候选
/// 核心职责：
/// - 将未绑定宠物的近期储物柜食品变化转成 Agent 追问候选
/// - 明确标记为待确认线索，避免被误用为摄入事实
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PetDietConfirmationCandidate {
    pub food_item_id: Uuid,
    pub food_name: String,
    pub category: String,
    pub candidate_kind: String,
    pub fact_strength: String,
    pub source_change_kind: String,
    pub source_question: String,
}

/// PetDietConfirmationCandidates 宠物饮食待确认候选集合
/// 核心职责：
/// - 汇总 Agent 需要向用户确认的可能换粮/新食品线索
/// - 保持候选和强事实读模型分离
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PetDietConfirmationCandidates {
    pub candidates: Vec<PetDietConfirmationCandidate>,
}

/// ConfirmPetDietCandidateInput 确认饮食候选输入
/// 核心职责：
/// - 承载用户对 Agent 追问候选的确认结果
/// - 明确是否需要派生饮食配置变更
#[derive(Debug, Clone)]
pub struct ConfirmPetDietCandidateInput {
    pub pet_id: Uuid,
    pub food_item_id: Uuid,
    pub confirmed_by_user_id: Uuid,
    pub confirmed_fact_kind: String,
    pub source_question: String,
    pub derive_diet_change: bool,
    pub derive_feeding_correction: bool,
}

/// ConfirmPetDietCandidateResult 确认饮食候选结果
/// 核心职责：
/// - 返回确认事实事件和可选派生配置
/// - 让 HTTP 层输出稳定可追溯 ID
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConfirmPetDietCandidateResult {
    pub confirmed_event_id: Uuid,
    pub assignment_id: Option<Uuid>,
    pub correction_event_id: Option<Uuid>,
}

/// NewFoodInventoryItem 新建食品资产输入
/// 核心职责：
/// - 汇总创建储物柜食品资产所需字段
/// - 保持 HTTP DTO 与仓储写入解耦
#[derive(Debug, Clone)]
pub struct NewFoodInventoryItem {
    pub scope_type: FoodScopeType,
    pub scope_id: Uuid,
    pub created_by_user_id: Uuid,
    pub name: String,
    pub brand: Option<String>,
    pub category: FoodInventoryCategory,
    pub inventory_status: FoodInventoryStatus,
    pub quantity: i32,
    pub unit: Option<String>,
    pub spec: Option<String>,
    pub expiry_date: Option<NaiveDate>,
    pub cover_asset_id: Option<Uuid>,
    pub barcode: Option<String>,
    pub source_kind: FoodSourceKind,
    pub note: Option<String>,
}

/// UpdateFoodInventoryItem 编辑食品资产输入
/// 核心职责：
/// - 表达可编辑的食品资产字段
/// - 保持不可编辑字段由应用服务校验
#[derive(Debug, Clone, Default)]
pub struct UpdateFoodInventoryItem {
    pub item_id: Uuid,
    pub editor_user_id: Uuid,
    pub name: Option<String>,
    pub brand: Option<String>,
    pub category: Option<FoodInventoryCategory>,
    pub inventory_status: Option<FoodInventoryStatus>,
    pub quantity: Option<i32>,
    pub unit: Option<String>,
    pub spec: Option<String>,
    pub expiry_date: Option<NaiveDate>,
    pub cover_asset_id: Option<Uuid>,
    pub barcode: Option<String>,
    pub note: Option<String>,
}

/// FoodInventoryRepository 食品资产仓储端口
/// 核心职责：
/// - 持久化用户/家庭空间储物柜食品资产
/// - 支持 CRUD、归档、补库存和分类查询
#[async_trait]
pub trait FoodInventoryRepository: Send + Sync {
    async fn create_item(&self, input: NewFoodInventoryItem) -> PetResult<FoodInventoryItem>;

    async fn list_items(
        &self,
        scope_type: FoodScopeType,
        scope_id: Uuid,
        category: Option<FoodInventoryCategory>,
        status: Option<FoodInventoryStatus>,
    ) -> PetResult<Vec<FoodInventoryItem>>;

    async fn find_item(&self, item_id: Uuid) -> PetResult<Option<FoodInventoryItem>>;

    async fn update_item(&self, input: UpdateFoodInventoryItem) -> PetResult<FoodInventoryItem>;

    async fn archive_item(
        &self,
        item_id: Uuid,
        editor_user_id: Uuid,
    ) -> PetResult<FoodInventoryItem>;

    async fn restore_item(
        &self,
        item_id: Uuid,
        editor_user_id: Uuid,
        status: FoodInventoryStatus,
    ) -> PetResult<FoodInventoryItem>;

    async fn restock_item(
        &self,
        item_id: Uuid,
        editor_user_id: Uuid,
        quantity: i32,
    ) -> PetResult<FoodInventoryItem>;
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
    /// user_id 用于授权校验，非 owner/guardian 不可读取
    async fn load_identity_context(
        &self,
        pet_id: Uuid,
        user_id: Uuid,
    ) -> PetResult<PetIdentityContext>;
}
