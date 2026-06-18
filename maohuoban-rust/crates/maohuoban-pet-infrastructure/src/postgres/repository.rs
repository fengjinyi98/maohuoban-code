use async_trait::async_trait;
use chrono::{DateTime, Datelike, Duration, Utc};
use maohuoban_pet_application::pet::{
    BindUploadedPetMediaInput, DeletePetProfile, MediaAssetDisplayMetadata, NewPetEvent,
    NewPetProfile, PendingPetLivePhotoUploadInput, PendingPetMediaUploadInput, PetRepository,
    RestorePetProfile, TradePetImport, TradePetImportInput, UpdatePetProfile,
};
use maohuoban_pet_domain::pet::{
    PetEvent, PetMediaUploadResult, PetNameEditPolicy, PetProfile, PetResult, PetTimeline,
};
use sqlx::PgPool;
use uuid::Uuid;

mod event_queries;
mod event_rows;
mod media_commands;
mod media_metadata;
mod profile_commands;
mod profile_create;
mod profile_crud;
mod profile_queries;
mod profile_update;
mod rows;
mod storage;
mod trade_import;

use storage::to_infrastructure_error;

const NAME_EDIT_MAX_COUNT: i32 = 5;
const NAME_EDIT_WINDOW_DAYS: i32 = 30;

/// PostgresPetRepository PostgreSQL 宠物仓储
/// 核心职责：
/// - 持久化宠物档案和宠物事件账本
/// - 通过数据库索引支撑首页和详情页时间线读取
#[derive(Debug, Clone)]
pub struct PostgresPetRepository {
    pub(crate) pool: PgPool,
}

impl PostgresPetRepository {
    #[must_use]
    pub const fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    async fn attach_name_edit_policy(&self, mut pet: PetProfile) -> PetResult<PetProfile> {
        pet.name_edit_policy = Some(self.load_name_edit_policy(pet.id).await?);
        Ok(pet)
    }

    async fn load_name_edit_policy(&self, pet_id: Uuid) -> PetResult<PetNameEditPolicy> {
        let (used_count, first_changed_at) = sqlx::query_as::<_, (i64, Option<DateTime<Utc>>)>(
            r#"
                SELECT COUNT(*) AS used_count, MIN(changed_at) AS first_changed_at
                FROM pet_profile_name_changes
                WHERE pet_id = $1
                  AND changed_at >= now() - interval '30 days'
                "#,
        )
        .bind(pet_id)
        .fetch_one(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        Ok(name_edit_policy(used_count, first_changed_at))
    }

    async fn record_name_change(
        &self,
        pet_id: Uuid,
        owner_user_id: Uuid,
        old_name: &str,
        new_name: &str,
    ) -> PetResult<()> {
        sqlx::query(
            r#"
            INSERT INTO pet_profile_name_changes (
                id,
                pet_id,
                owner_user_id,
                old_name,
                new_name
            )
            VALUES ($1, $2, $3, $4, $5)
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(pet_id)
        .bind(owner_user_id)
        .bind(old_name)
        .bind(new_name)
        .execute(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        Ok(())
    }
}

fn name_edit_policy(used_count: i64, first_changed_at: Option<DateTime<Utc>>) -> PetNameEditPolicy {
    let used_count = i32::try_from(used_count).unwrap_or(i32::MAX);
    let remaining_count = NAME_EDIT_MAX_COUNT.saturating_sub(used_count).max(0);
    let window_ends_at = first_changed_at
        .map(|changed_at| changed_at + Duration::days(i64::from(NAME_EDIT_WINDOW_DAYS)));
    let display_text = window_ends_at.map_or_else(
        || format!("{NAME_EDIT_WINDOW_DAYS} 天内最多修改 {NAME_EDIT_MAX_COUNT} 次名字。"),
        |ends_at| {
            format!(
                "{}月{}日前还可以修改 {remaining_count} 次名字。",
                ends_at.month(),
                ends_at.day()
            )
        },
    );

    PetNameEditPolicy {
        max_count: NAME_EDIT_MAX_COUNT,
        used_count,
        remaining_count,
        window_days: NAME_EDIT_WINDOW_DAYS,
        window_ends_at,
        display_text,
    }
}

#[async_trait]
impl PetRepository for PostgresPetRepository {
    async fn create_pet_profile(&self, input: NewPetProfile) -> PetResult<PetProfile> {
        self.create_pet_profile_command(input).await
    }

    async fn find_pet_for_owner(
        &self,
        pet_id: Uuid,
        owner_user_id: Uuid,
    ) -> PetResult<Option<PetProfile>> {
        self.find_pet_for_owner_query(pet_id, owner_user_id).await
    }

    async fn list_pet_profiles_for_owner(&self, owner_user_id: Uuid) -> PetResult<Vec<PetProfile>> {
        self.list_pet_profiles_for_owner_query(owner_user_id).await
    }

    async fn update_pet_profile(
        &self,
        input: UpdatePetProfile,
    ) -> PetResult<maohuoban_pet_application::pet::UpdatePetProfileResult> {
        self.update_pet_profile_command(input).await
    }

    async fn soft_delete_pet_profile(&self, input: DeletePetProfile) -> PetResult<PetProfile> {
        self.soft_delete_pet_profile_command(input).await
    }

    async fn restore_pet_profile(&self, input: RestorePetProfile) -> PetResult<PetProfile> {
        self.restore_pet_profile_command(input).await
    }

    async fn upload_pending_pet_media(
        &self,
        input: PendingPetMediaUploadInput,
    ) -> PetResult<PetMediaUploadResult> {
        self.upload_pending_pet_media_command(input).await
    }

    async fn upload_pending_pet_live_photo(
        &self,
        input: PendingPetLivePhotoUploadInput,
    ) -> PetResult<PetMediaUploadResult> {
        self.upload_pending_pet_live_photo_command(input).await
    }

    async fn bind_uploaded_pet_media(
        &self,
        input: BindUploadedPetMediaInput,
    ) -> PetResult<PetMediaUploadResult> {
        self.bind_uploaded_pet_media_command(input).await
    }

    async fn list_media_display_metadata(
        &self,
        asset_ids: &[Uuid],
    ) -> PetResult<Vec<MediaAssetDisplayMetadata>> {
        self.list_media_display_metadata_query(asset_ids).await
    }

    async fn create_pet_event(&self, input: NewPetEvent) -> PetResult<PetEvent> {
        self.create_pet_event_command(input).await
    }

    async fn import_trade_pet(&self, input: TradePetImportInput) -> PetResult<TradePetImport> {
        self.import_trade_pet_command(input).await
    }

    async fn load_pet_timeline(
        &self,
        owner_user_id: Uuid,
        pet_id: Uuid,
        limit: i64,
    ) -> PetResult<PetTimeline> {
        self.load_pet_timeline_query(owner_user_id, pet_id, limit)
            .await
    }

    async fn load_pet_event_detail(
        &self,
        owner_user_id: Uuid,
        event_id: Uuid,
    ) -> PetResult<Option<PetEvent>> {
        self.load_pet_event_detail_query(owner_user_id, event_id)
            .await
    }
}
