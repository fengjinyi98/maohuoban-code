use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// HomeGalleryAlbumSummary 首页相册摘要
/// 核心职责：
/// - 为首页相册入口提供用户级相册展示数据
/// - 避免首页承载完整相册业务模型
/// - 保留可选来源宠物，确保首页只表达入口上下文
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct HomeGalleryAlbumSummary {
    pub id: Uuid,
    pub pet_id: Option<Uuid>,
    pub title: String,
    pub cover_asset_id: Option<Uuid>,
    pub cover_url: Option<String>,
    pub photo_count: i32,
}
