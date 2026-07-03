use uuid::Uuid;

/// CreatePetAlbumInput 创建宠物相册输入
/// 核心职责：
/// - 承接相册基础信息
/// - 保留当前用户和宠物授权上下文
#[derive(Debug, Clone)]
pub struct CreatePetAlbumInput {
    pub pet_id: Uuid,
    pub owner_user_id: Uuid,
    pub title: String,
    pub description: Option<String>,
    pub is_private: bool,
    pub is_pinned: bool,
}
