use async_trait::async_trait;
use maohuoban_pet_domain::pet::{HomeGalleryAlbumSummary, PetAlbum, PetAlbumAsset, PetResult};
use uuid::Uuid;

use super::{AddPetAlbumAssetInput, CreatePetAlbumInput, PetAlbumAssetPage, PetAlbumListPage};
use crate::pet::UpdatePetAlbumInput;

/// PetAlbumRepository 宠物相册仓储端口
/// 核心职责：
/// - 持久化用户相册空间与相册照片
/// - 保留可选来源宠物作为筛选上下文
/// - 为首页提供相册摘要投影
#[async_trait]
pub trait PetAlbumRepository: Send + Sync {
    async fn create_pet_album(&self, input: CreatePetAlbumInput) -> PetResult<PetAlbum>;

    async fn list_user_pet_albums(
        &self,
        owner_user_id: Uuid,
        limit: i64,
        cursor: Option<String>,
    ) -> PetResult<PetAlbumListPage>;

    async fn load_pet_album(
        &self,
        album_id: Uuid,
        owner_user_id: Uuid,
    ) -> PetResult<Option<PetAlbum>>;

    async fn update_pet_album(&self, input: UpdatePetAlbumInput) -> PetResult<PetAlbum>;

    async fn archive_pet_album(&self, album_id: Uuid, owner_user_id: Uuid) -> PetResult<PetAlbum>;

    async fn add_pet_album_asset(&self, input: AddPetAlbumAssetInput) -> PetResult<PetAlbumAsset>;

    async fn list_pet_album_assets(
        &self,
        album_id: Uuid,
        owner_user_id: Uuid,
        limit: i64,
        cursor: Option<String>,
    ) -> PetResult<PetAlbumAssetPage>;

    async fn remove_pet_album_asset(
        &self,
        album_asset_id: Uuid,
        owner_user_id: Uuid,
    ) -> PetResult<PetAlbum>;

    async fn list_home_gallery_album_summaries(
        &self,
        pet_id: Uuid,
        owner_user_id: Uuid,
        limit: i64,
    ) -> PetResult<Vec<HomeGalleryAlbumSummary>>;
}
