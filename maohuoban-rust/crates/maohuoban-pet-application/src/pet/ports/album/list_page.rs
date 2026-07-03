use maohuoban_pet_domain::pet::PetAlbum;

/// PetAlbumListPage 宠物相册分页
/// 核心职责：
/// - 返回相册列表页数据
/// - 使用 opaque cursor 承接下一页查询
#[derive(Debug, Clone)]
pub struct PetAlbumListPage {
    pub items: Vec<PetAlbum>,
    pub next_cursor: Option<String>,
}
