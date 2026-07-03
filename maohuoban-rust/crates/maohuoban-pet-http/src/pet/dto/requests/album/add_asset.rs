use chrono::{DateTime, Utc};
use maohuoban_pet_application::pet::AddPetAlbumAssetInput;
use serde::Deserialize;
use uuid::Uuid;

/// AddPetAlbumAssetRequest 添加相册照片请求
/// 核心职责：
/// - 接收已上传媒体资产 ID 和照片说明
/// - 转换为相册照片添加命令
#[derive(Debug, Deserialize)]
pub(crate) struct AddPetAlbumAssetRequest {
    asset_id: Uuid,
    caption: Option<String>,
    sort_taken_at: Option<DateTime<Utc>>,
}

impl AddPetAlbumAssetRequest {
    pub(crate) fn into_input(self, album_id: Uuid, owner_user_id: Uuid) -> AddPetAlbumAssetInput {
        AddPetAlbumAssetInput {
            album_id,
            owner_user_id,
            asset_id: self.asset_id,
            caption: self.caption,
            sort_taken_at: self.sort_taken_at,
        }
    }
}
