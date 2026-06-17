use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// HomeDashboardSnapshot 首页聚合快照
/// 核心职责：
/// - 承载首页所有 section 的稳定读模型
/// - 让 HTTP 和 iOS 只依赖聚合结果而非深层业务实现
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct HomeDashboardSnapshot {
    pub identity: HomeIdentity,
    pub selected_pet: Option<PetHeroSummary>,
    pub pet_switcher: Vec<PetSwitchItem>,
    pub care_summary: Option<CareSummary>,
    pub reminders: Vec<HomeReminder>,
    pub quick_actions: Vec<HomeAction>,
    pub partner_recommendation: Option<PartnerRecommendation>,
    pub recent_timeline: Vec<HomeTimelineEvent>,
    pub merchant_dashboard: Option<MerchantDashboardSummary>,
    pub empty_state: Option<HomeEmptyState>,
    pub recommended_content: Vec<RecommendedContent>,
}

/// HomeIdentity 首页身份摘要
/// 核心职责：
/// - 表达当前首页形态
/// - 为普通用户、空态和认证商家切换提供稳定字段
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct HomeIdentity {
    pub kind: HomeIdentityKind,
    pub display_name: String,
    pub city: Option<String>,
    pub verification_badge: Option<String>,
}

/// HomeIdentityKind 首页身份类型
/// 核心职责：
/// - 固定首页形态枚举
/// - 驱动客户端选择普通首页、空态或商家工作台
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum HomeIdentityKind {
    NewUser,
    PetOwner,
    FamilyCaretaker,
    CertifiedMerchant,
    UnverifiedMerchant,
}

/// PetHeroSummary 宠物主卡摘要
/// 核心职责：
/// - 承载首页首屏宠物主体信息
/// - 避免首页依赖完整宠物档案字段
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct PetHeroSummary {
    pub id: Uuid,
    pub name: String,
    pub species: PetSpecies,
    pub breed: String,
    pub sex: PetSex,
    pub age_text: String,
    pub status_text: String,
    pub updated_text: String,
    pub avatar_url: Option<String>,
    #[serde(default)]
    pub avatar_width: Option<i32>,
    #[serde(default)]
    pub avatar_height: Option<i32>,
    #[serde(default)]
    pub hero_image_url: Option<String>,
    #[serde(default)]
    pub hero_image_width: Option<i32>,
    #[serde(default)]
    pub hero_image_height: Option<i32>,
    #[serde(default)]
    pub hero_video_url: Option<String>,
    #[serde(default)]
    pub hero_video_width: Option<i32>,
    #[serde(default)]
    pub hero_video_height: Option<i32>,
    #[serde(default)]
    pub hero_theme_color_hex: Option<String>,
    #[serde(default)]
    pub hero_content_color_scheme: Option<String>,
    #[serde(default)]
    pub profile_number: Option<String>,
    #[serde(default)]
    pub microchip_number: Option<String>,
    pub birthday: Option<chrono::NaiveDate>,
    #[serde(default)]
    pub arrival_date: Option<chrono::NaiveDate>,
    #[serde(default)]
    pub weight_grams: Option<i32>,
    #[serde(default)]
    pub neuter_status: Option<PetNeuterStatus>,
    #[serde(default)]
    pub personality_tags: Vec<String>,
    #[serde(default)]
    pub note: Option<String>,
    pub companionship_days: Option<i32>,
}

/// PetSpecies 宠物物种
/// 核心职责：
/// - 约束首页和事件模型中的物种表达
/// - 为后续猫狗以外物种保留扩展枚举
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum PetSpecies {
    Dog,
    Cat,
    Other,
}

/// PetSex 宠物性别
/// 核心职责：
/// - 统一宠物基础档案和首页主卡性别表达
/// - 支持未知状态
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum PetSex {
    Female,
    Male,
    Unknown,
}

/// PetNeuterStatus 宠物绝育状态
/// 核心职责：
/// - 承载首页进入编辑页所需档案字段
/// - 与宠物档案后端枚举保持同名语义
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum PetNeuterStatus {
    Unknown,
    Intact,
    Neutered,
}

/// PetSwitchItem 宠物切换项
/// 核心职责：
/// - 承载多宠用户和商家多宠切换入口
/// - 让首页保持当前宠物和其他宠物的轻量索引
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct PetSwitchItem {
    pub id: Uuid,
    pub name: String,
    pub species: PetSpecies,
    pub avatar_url: Option<String>,
    #[serde(default)]
    pub avatar_width: Option<i32>,
    #[serde(default)]
    pub avatar_height: Option<i32>,
    #[serde(default)]
    pub profile_number: Option<String>,
    #[serde(default)]
    pub microchip_number: Option<String>,
    #[serde(default)]
    pub birthday: Option<chrono::NaiveDate>,
    #[serde(default)]
    pub arrival_date: Option<chrono::NaiveDate>,
    #[serde(default)]
    pub weight_grams: Option<i32>,
    #[serde(default)]
    pub neuter_status: Option<PetNeuterStatus>,
    #[serde(default)]
    pub personality_tags: Vec<String>,
    #[serde(default)]
    pub note: Option<String>,
    pub is_selected: bool,
}

/// CareSummary 今日照护摘要
/// 核心职责：
/// - 聚合今日健康与照护指标
/// - 为首页指标卡提供已计算展示数据
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct CareSummary {
    pub title: String,
    pub metrics: Vec<CareMetric>,
}

/// CareMetric 今日照护指标
/// 核心职责：
/// - 表达首页照护指标的名称和值
/// - 保留趋势和状态文案扩展位
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct CareMetric {
    pub kind: CareMetricKind,
    pub title: String,
    pub value_text: String,
    pub status_text: String,
}

/// CareMetricKind 照护指标类型
/// 核心职责：
/// - 固定首页常用照护指标
/// - 让客户端可以按类型选择图标和颜色 token
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum CareMetricKind {
    Appetite,
    Mood,
    Excretion,
    Weight,
}

/// HomeReminder 首页提醒摘要
/// 核心职责：
/// - 承载近期待处理提醒
/// - 与完整提醒模块保持入口关系
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct HomeReminder {
    pub id: Uuid,
    pub kind: HomeReminderKind,
    pub title: String,
    pub subtitle: String,
    pub due_text: String,
}

/// HomeReminderKind 提醒类型
/// 核心职责：
/// - 固定首页提醒分类
/// - 支持客户端按类型展示图标
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum HomeReminderKind {
    Vaccine,
    Deworming,
    FollowUp,
    MerchantTask,
    CompleteHealthRecord,
}

/// HomeAction 首页快捷动作
/// 核心职责：
/// - 表达首页可点击业务入口
/// - 将动作语义稳定传递给客户端路由
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct HomeAction {
    pub kind: HomeActionKind,
    pub title: String,
    pub subtitle: Option<String>,
}

/// HomeActionKind 首页动作类型
/// 核心职责：
/// - 固定首页首批快捷动作
/// - 为客户端路由和可访问性测试提供稳定语义
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum HomeActionKind {
    CreatePet,
    DailyRecord,
    HealthRecord,
    BookHospital,
    ImportTradePet,
    AddMerchantPet,
    PublishAvailableStatus,
}

/// PartnerRecommendation 今日伙伴推荐
/// 核心职责：
/// - 表达一条高质量宠物关系提示
/// - 将首页关系惊喜和宠物世界推荐解耦
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct PartnerRecommendation {
    pub pet_id: Uuid,
    pub pet_name: String,
    pub relationship_kind: PartnerRelationshipKind,
    pub title: String,
    pub subtitle: String,
    pub distance_text: Option<String>,
}

/// PartnerRelationshipKind 宠物关系类型
/// 核心职责：
/// - 固定首页关系解释语义
/// - 支持同窝、同城、同病种、同医院和同来源推荐
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum PartnerRelationshipKind {
    SameLitter,
    SameCity,
    SameCondition,
    SameHospital,
    SameSource,
}

/// HomeTimelineEvent 首页时间线事件
/// 核心职责：
/// - 承载最近关键事件摘要
/// - 隔离完整事件账本和首页展示模型
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct HomeTimelineEvent {
    pub id: Uuid,
    pub event_kind: HomeTimelineEventKind,
    pub title: String,
    pub subtitle: String,
    pub occurred_text: String,
}

/// HomeTimelineEventKind 首页事件类型
/// 核心职责：
/// - 固定首页最近时间线常用类型
/// - 让客户端可稳定映射视觉样式
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum HomeTimelineEventKind {
    Daily,
    Weight,
    Vaccine,
    Deworming,
    Health,
    Merchant,
}

/// MerchantDashboardSummary 商家首页工作台摘要
/// 核心职责：
/// - 承载认证商家的多宠经营状态
/// - 为窝次、待办和在售状态提供首页入口
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct MerchantDashboardSummary {
    pub merchant_id: Uuid,
    pub merchant_name: String,
    pub status_counts: Vec<MerchantStatusCount>,
    pub litters: Vec<MerchantLitterSummary>,
    pub pending_tasks: Vec<HomeReminder>,
    pub recent_events: Vec<HomeTimelineEvent>,
}

/// MerchantStatusCount 商家宠物状态统计
/// 核心职责：
/// - 表达商家多宠看板的数量摘要
/// - 支持按状态筛选进入多宠管理
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct MerchantStatusCount {
    pub status: MerchantPetStatus,
    pub title: String,
    pub count: u32,
}

/// MerchantPetStatus 商家宠物经营状态
/// 核心职责：
/// - 固定商家多宠状态枚举
/// - 支持在售、预定、已售和待补记录等看板筛选
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum MerchantPetStatus {
    Available,
    Reserved,
    Sold,
    NeedsExam,
    NeedsRecord,
}

/// MerchantLitterSummary 商家窝次摘要
/// 核心职责：
/// - 承载首页需要展示的窝次和父母关系入口
/// - 为后续完整关系树页面提供导航上下文
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct MerchantLitterSummary {
    pub id: Uuid,
    pub name: String,
    pub parent_text: String,
    pub born_text: String,
    pub available_count: u32,
}

/// HomeEmptyState 首页空态
/// 核心职责：
/// - 表达无宠物、未认证、已认证无宠物等引导状态
/// - 将主操作和辅助内容明确区分
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct HomeEmptyState {
    pub kind: HomeEmptyStateKind,
    pub title: String,
    pub subtitle: String,
    pub primary_action: HomeAction,
}

/// HomeEmptyStateKind 首页空态类型
/// 核心职责：
/// - 固定首页空态场景
/// - 让客户端按场景展示对应主操作
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum HomeEmptyStateKind {
    CreateFirstPet,
    ImportTradePet,
    VerifyMerchant,
    AddMerchantPet,
}

/// RecommendedContent 空态推荐内容
/// 核心职责：
/// - 为无宠物用户提供辅助内容
/// - 保持首页主操作仍指向宠物档案创建
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct RecommendedContent {
    pub id: Uuid,
    pub kind: RecommendedContentKind,
    pub title: String,
    pub source_text: String,
}

/// RecommendedContentKind 推荐内容类型
/// 核心职责：
/// - 固定空态可展示的内容来源
/// - 为后续接入宠物世界推荐服务预留类型
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum RecommendedContentKind {
    Ugc,
    Guide,
    LocalService,
}
