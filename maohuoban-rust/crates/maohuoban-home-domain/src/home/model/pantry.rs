use serde::{Deserialize, Serialize};

/// HomePantryPreviewItem 首页储物柜预览项
/// 核心职责：
/// - 表达空间级储物柜近期食品资产
/// - 为 iOS 首页储物柜 section 提供稳定展示字段
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct HomePantryPreviewItem {
    pub id: String,
    pub title: String,
    pub subtitle: String,
    pub category: String,
    pub cover_url: Option<String>,
    pub diet_role_label: Option<String>,
}
