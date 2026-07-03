use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

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
    pub id: String,
    pub event_kind: HomeTimelineEventKind,
    pub title: String,
    pub subtitle: String,
    pub occurred_text: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub occurred_at: Option<DateTime<Utc>>,
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
