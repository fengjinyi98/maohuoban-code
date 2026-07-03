use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// HomeGalleryAlbumSummary 首页相册摘要
/// 核心职责：
/// - 为首页相册 section 提供用户级相册入口数据
/// - 避免首页读取完整相册照片列表
/// - 保留可选来源宠物，避免把首页当前宠物当作相册数据边界
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct HomeGalleryAlbumSummary {
    pub id: Uuid,
    pub pet_id: Option<Uuid>,
    pub title: String,
    pub cover_asset_id: Option<Uuid>,
    pub cover_url: Option<String>,
    pub photo_count: i32,
}
