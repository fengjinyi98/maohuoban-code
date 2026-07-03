use maohuoban_pet_domain::pet::PetAlbumAsset;

/// PetAlbumAssetPage 宠物相册照片分页
/// 核心职责：
/// - 返回相册照片列表页数据
/// - 使用 opaque cursor 承接下一页查询
#[derive(Debug, Clone)]
pub struct PetAlbumAssetPage {
    pub items: Vec<PetAlbumAsset>,
    pub next_cursor: Option<String>,
}
