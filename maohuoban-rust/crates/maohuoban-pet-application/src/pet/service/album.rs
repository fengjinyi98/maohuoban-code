use maohuoban_pet_domain::pet::{
    HomeGalleryAlbumSummary, MediaUsageKind, PetAlbum, PetAlbumAsset, PetError,
    PetMediaUploadResult, PetResult,
};
use uuid::Uuid;

use super::PetService;
use super::validation::{normalize_compact_text, normalize_optional_compact_text, validate_text};
use crate::pet::{
    AddPetAlbumAssetInput, CreatePetAlbumInput, PendingPetMediaUploadInput, PetAlbumAssetPage,
    PetAlbumListPage, UpdatePetAlbumInput,
};

const DEFAULT_ALBUM_PAGE_LIMIT: i64 = 20;
const MAX_ALBUM_PAGE_LIMIT: i64 = 50;

impl PetService {
    pub async fn create_pet_album(&self, mut input: CreatePetAlbumInput) -> PetResult<PetAlbum> {
        input.title = normalize_compact_text(&input.title);
        input.description = normalize_optional_compact_text(input.description);
        validate_text("相册标题", &input.title)?;
        if let Some(source_pet_id) = input.source_pet_id {
            self.ensure_pet_access(source_pet_id, input.owner_user_id)
                .await?;
        }
        self.album_repository.create_pet_album(input).await
    }

    /// list_user_pet_albums 查询用户相册空间
    /// 核心职责：
    /// - 按 owner_user_id 返回用户所有宠物相册
    /// - 不把当前宠物作为相册所有权或数据源边界
    pub async fn list_user_pet_albums(
        &self,
        owner_user_id: Uuid,
        limit: Option<i64>,
        cursor: Option<String>,
    ) -> PetResult<PetAlbumListPage> {
        self.album_repository
            .list_user_pet_albums(owner_user_id, page_limit(limit), cursor)
            .await
    }

    pub async fn load_pet_album(&self, album_id: Uuid, owner_user_id: Uuid) -> PetResult<PetAlbum> {
        self.album_repository
            .load_pet_album(album_id, owner_user_id)
            .await?
            .ok_or(PetError::PetAlbumNotFound)
    }

    pub async fn update_pet_album(&self, mut input: UpdatePetAlbumInput) -> PetResult<PetAlbum> {
        input.title = input.title.map(|title| normalize_compact_text(&title));
        input.description = normalize_optional_compact_text(input.description);
        if let Some(title) = input.title.as_deref() {
            validate_text("相册标题", title)?;
        }
        self.album_repository.update_pet_album(input).await
    }

    pub async fn archive_pet_album(
        &self,
        album_id: Uuid,
        owner_user_id: Uuid,
    ) -> PetResult<PetAlbum> {
        self.album_repository
            .archive_pet_album(album_id, owner_user_id)
            .await
    }

    pub async fn upload_pending_pet_album_photo(
        &self,
        mut input: PendingPetMediaUploadInput,
    ) -> PetResult<PetMediaUploadResult> {
        input.usage_kind = MediaUsageKind::PetAlbumPhoto;
        self.upload_pending_pet_media(input).await
    }

    pub async fn upload_pending_pet_album_photo_with_source_pet(
        &self,
        source_pet_id: Uuid,
        mut input: PendingPetMediaUploadInput,
    ) -> PetResult<PetMediaUploadResult> {
        self.ensure_pet_access(source_pet_id, input.owner_user_id)
            .await?;
        input.usage_kind = MediaUsageKind::PetAlbumPhoto;
        self.upload_pending_pet_media(input).await
    }

    pub async fn add_pet_album_asset(
        &self,
        mut input: AddPetAlbumAssetInput,
    ) -> PetResult<PetAlbumAsset> {
        input.caption = normalize_optional_compact_text(input.caption);
        self.album_repository.add_pet_album_asset(input).await
    }

    pub async fn list_pet_album_assets(
        &self,
        album_id: Uuid,
        owner_user_id: Uuid,
        limit: Option<i64>,
        cursor: Option<String>,
    ) -> PetResult<PetAlbumAssetPage> {
        self.album_repository
            .list_pet_album_assets(album_id, owner_user_id, page_limit(limit), cursor)
            .await
    }

    pub async fn remove_pet_album_asset(
        &self,
        album_asset_id: Uuid,
        owner_user_id: Uuid,
    ) -> PetResult<PetAlbum> {
        self.album_repository
            .remove_pet_album_asset(album_asset_id, owner_user_id)
            .await
    }

    pub async fn list_home_gallery_album_summaries(
        &self,
        pet_id: Uuid,
        owner_user_id: Uuid,
        limit: i64,
    ) -> PetResult<Vec<HomeGalleryAlbumSummary>> {
        self.ensure_pet_access(pet_id, owner_user_id).await?;
        self.album_repository
            .list_home_gallery_album_summaries(pet_id, owner_user_id, page_limit(Some(limit)))
            .await
    }

    async fn ensure_pet_access(&self, pet_id: Uuid, owner_user_id: Uuid) -> PetResult<()> {
        if self
            .repository
            .authorize_pet_access(pet_id, owner_user_id)
            .await?
            .is_none()
        {
            return Err(PetError::PetNotFound);
        }
        Ok(())
    }
}

fn page_limit(limit: Option<i64>) -> i64 {
    limit
        .unwrap_or(DEFAULT_ALBUM_PAGE_LIMIT)
        .clamp(1, MAX_ALBUM_PAGE_LIMIT)
}
