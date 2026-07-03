mod commands;
mod cursor;
mod errors;
mod queries;
mod rows;

use async_trait::async_trait;
use maohuoban_pet_application::pet::{
    AddPetAlbumAssetInput, CreatePetAlbumInput, PetAlbumAssetPage, PetAlbumListPage,
    PetAlbumRepository, UpdatePetAlbumInput,
};
use maohuoban_pet_domain::pet::{HomeGalleryAlbumSummary, PetAlbum, PetAlbumAsset, PetResult};
use sqlx::PgPool;
use uuid::Uuid;

/// PostgresPetAlbumRepository PostgreSQL 宠物相册仓储
/// 核心职责：
/// - 持久化宠物相册和相册照片关系
/// - 为 Pet 域与首页入口提供分页读模型
#[derive(Debug, Clone)]
pub struct PostgresPetAlbumRepository {
    pool: PgPool,
}

impl PostgresPetAlbumRepository {
    #[must_use]
    pub const fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl PetAlbumRepository for PostgresPetAlbumRepository {
    async fn create_pet_album(&self, input: CreatePetAlbumInput) -> PetResult<PetAlbum> {
        self.create_pet_album_command(input).await
    }

    async fn list_pet_albums(
        &self,
        pet_id: Uuid,
        owner_user_id: Uuid,
        limit: i64,
        cursor: Option<String>,
    ) -> PetResult<PetAlbumListPage> {
        self.list_pet_albums_query(pet_id, owner_user_id, limit, cursor)
            .await
    }

    async fn load_pet_album(
        &self,
        album_id: Uuid,
        owner_user_id: Uuid,
    ) -> PetResult<Option<PetAlbum>> {
        self.load_pet_album_query(album_id, owner_user_id).await
    }

    async fn update_pet_album(&self, input: UpdatePetAlbumInput) -> PetResult<PetAlbum> {
        self.update_pet_album_command(input).await
    }

    async fn archive_pet_album(&self, album_id: Uuid, owner_user_id: Uuid) -> PetResult<PetAlbum> {
        self.archive_pet_album_command(album_id, owner_user_id)
            .await
    }

    async fn add_pet_album_asset(&self, input: AddPetAlbumAssetInput) -> PetResult<PetAlbumAsset> {
        self.add_pet_album_asset_command(input).await
    }

    async fn list_pet_album_assets(
        &self,
        album_id: Uuid,
        owner_user_id: Uuid,
        limit: i64,
        cursor: Option<String>,
    ) -> PetResult<PetAlbumAssetPage> {
        self.list_pet_album_assets_query(album_id, owner_user_id, limit, cursor)
            .await
    }

    async fn remove_pet_album_asset(
        &self,
        album_asset_id: Uuid,
        owner_user_id: Uuid,
    ) -> PetResult<PetAlbum> {
        self.remove_pet_album_asset_command(album_asset_id, owner_user_id)
            .await
    }

    async fn list_home_gallery_album_summaries(
        &self,
        pet_id: Uuid,
        owner_user_id: Uuid,
        limit: i64,
    ) -> PetResult<Vec<HomeGalleryAlbumSummary>> {
        self.list_home_gallery_album_summaries_query(pet_id, owner_user_id, limit)
            .await
    }
}
