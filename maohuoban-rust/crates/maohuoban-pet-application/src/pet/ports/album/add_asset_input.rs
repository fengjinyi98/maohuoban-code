use chrono::{DateTime, Utc};
use uuid::Uuid;

/// AddPetAlbumAssetInput 添加相册照片输入
/// 核心职责：
/// - 将已上传的媒体资产加入相册
/// - 承载照片说明和排序时间
#[derive(Debug, Clone)]
pub struct AddPetAlbumAssetInput {
    pub album_id: Uuid,
    pub owner_user_id: Uuid,
    pub asset_id: Uuid,
    pub caption: Option<String>,
    pub sort_taken_at: Option<DateTime<Utc>>,
}
