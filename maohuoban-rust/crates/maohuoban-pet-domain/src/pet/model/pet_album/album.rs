use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// PetAlbum 宠物相册
/// 核心职责：
/// - 表达用户相册空间内的照片集合
/// - 通过可选 pet_id 保留来源宠物或默认筛选上下文
/// - 承载首页相册入口和相册详情页所需摘要字段
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct PetAlbum {
    pub id: Uuid,
    pub pet_id: Option<Uuid>,
    pub owner_user_id: Uuid,
    pub title: String,
    pub description: Option<String>,
    pub is_private: bool,
    pub is_pinned: bool,
    pub cover_asset_id: Option<Uuid>,
    pub cover_url: Option<String>,
    pub photo_count: i32,
    pub archived_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}
