use uuid::Uuid;

/// UpdatePetAlbumInput 更新宠物相册输入
/// 核心职责：
/// - 表达相册元信息的局部更新
/// - 保持封面和置顶策略由业务服务统一编排
#[derive(Debug, Clone, Default)]
pub struct UpdatePetAlbumInput {
    pub album_id: Uuid,
    pub owner_user_id: Uuid,
    pub title: Option<String>,
    pub description: Option<String>,
    pub is_private: Option<bool>,
    pub is_pinned: Option<bool>,
    pub cover_asset_id: Option<Uuid>,
}
