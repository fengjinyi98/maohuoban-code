use maohuoban_pet_application::pet::CreatePetAlbumInput;
use serde::Deserialize;
use uuid::Uuid;

/// CreatePetAlbumRequest 创建宠物相册请求
/// 核心职责：
/// - 接收客户端相册基础字段
/// - 转换为应用服务创建命令
#[derive(Debug, Deserialize)]
pub(crate) struct CreatePetAlbumRequest {
    title: String,
    description: Option<String>,
    #[serde(default)]
    is_private: bool,
    #[serde(default)]
    is_pinned: bool,
}

impl CreatePetAlbumRequest {
    pub(crate) fn into_input(self, pet_id: Uuid, owner_user_id: Uuid) -> CreatePetAlbumInput {
        CreatePetAlbumInput {
            pet_id,
            owner_user_id,
            title: self.title,
            description: self.description,
            is_private: self.is_private,
            is_pinned: self.is_pinned,
        }
    }
}
