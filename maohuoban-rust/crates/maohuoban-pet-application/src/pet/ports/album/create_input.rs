use uuid::Uuid;

/// CreatePetAlbumInput 创建宠物相册输入
/// 核心职责：
/// - 承接相册基础信息
/// - 以 owner_user_id 表达用户相册空间归属
/// - 用 source_pet_id 保留可选来源宠物或默认筛选上下文
/// - 保留创建时选择的封面媒资
#[derive(Debug, Clone)]
pub struct CreatePetAlbumInput {
    pub owner_user_id: Uuid,
    pub source_pet_id: Option<Uuid>,
    pub title: String,
    pub description: Option<String>,
    pub is_private: bool,
    pub is_pinned: bool,
    pub cover_asset_id: Option<Uuid>,
}
