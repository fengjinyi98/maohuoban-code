use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// PetAlbumAsset 宠物相册照片条目
/// 核心职责：
/// - 记录媒体资产加入相册后的业务语义
/// - 通过可选 pet_id 保留照片来源宠物或后续筛选上下文
/// - 支持照片分页、封面选择和软移除
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct PetAlbumAsset {
    pub id: Uuid,
    pub album_id: Uuid,
    pub pet_id: Option<Uuid>,
    pub asset_id: Uuid,
    pub asset_url: String,
    pub added_by_user_id: Uuid,
    pub caption: Option<String>,
    pub sort_taken_at: DateTime<Utc>,
    pub removed_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}
