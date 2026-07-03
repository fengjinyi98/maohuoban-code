use maohuoban_pet_application::pet::CreatePetAlbumInput;
use serde::Deserialize;
use uuid::Uuid;

/// CreatePetAlbumRequest 创建宠物相册请求
/// 核心职责：
/// - 接收用户相册空间内的相册基础字段
/// - 保留可选来源宠物作为后续筛选上下文
/// - 转换为应用服务创建命令
#[derive(Debug, Deserialize)]
pub(crate) struct CreatePetAlbumRequest {
    source_pet_id: Option<Uuid>,
    title: String,
    description: Option<String>,
    #[serde(default)]
    is_private: bool,
    #[serde(default)]
    is_pinned: bool,
}

impl CreatePetAlbumRequest {
    pub(crate) fn into_input(
        self,
        source_pet_id: Option<Uuid>,
        owner_user_id: Uuid,
    ) -> CreatePetAlbumInput {
        CreatePetAlbumInput {
            owner_user_id,
            source_pet_id: source_pet_id.or(self.source_pet_id),
            title: self.title,
            description: self.description,
            is_private: self.is_private,
            is_pinned: self.is_pinned,
        }
    }
}
