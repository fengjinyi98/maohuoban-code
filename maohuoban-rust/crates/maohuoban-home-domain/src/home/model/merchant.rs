use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::activity::{HomeReminder, HomeTimelineEvent};

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
