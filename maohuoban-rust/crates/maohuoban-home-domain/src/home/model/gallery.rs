use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// HomeGalleryAlbumSummary 首页相册摘要
/// 核心职责：
/// - 为首页相册入口提供轻量展示数据
/// - 避免首页承载完整相册业务模型
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct HomeGalleryAlbumSummary {
    pub id: Uuid,
    pub pet_id: Uuid,
    pub title: String,
    pub cover_asset_id: Option<Uuid>,
    pub cover_url: Option<String>,
    pub photo_count: i32,
}
