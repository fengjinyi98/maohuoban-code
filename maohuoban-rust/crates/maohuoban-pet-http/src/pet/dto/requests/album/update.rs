use maohuoban_pet_application::pet::UpdatePetAlbumInput;
use serde::Deserialize;
use uuid::Uuid;

/// UpdatePetAlbumRequest 更新宠物相册请求
/// 核心职责：
/// - 接收相册元信息局部更新
/// - 转换为应用服务更新命令
#[derive(Debug, Deserialize)]
pub(crate) struct UpdatePetAlbumRequest {
    title: Option<String>,
    description: Option<String>,
    is_private: Option<bool>,
    is_pinned: Option<bool>,
    cover_asset_id: Option<Uuid>,
}

impl UpdatePetAlbumRequest {
    pub(crate) fn into_input(self, album_id: Uuid, owner_user_id: Uuid) -> UpdatePetAlbumInput {
        UpdatePetAlbumInput {
            album_id,
            owner_user_id,
            title: self.title,
            description: self.description,
            is_private: self.is_private,
            is_pinned: self.is_pinned,
            cover_asset_id: self.cover_asset_id,
        }
    }
}
