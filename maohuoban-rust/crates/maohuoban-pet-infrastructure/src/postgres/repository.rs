use async_trait::async_trait;
use chrono::{DateTime, Datelike, Duration, Utc};
use maohuoban_pet_application::pet::{
    AddPetExternalIdentifier, AddPetGuardian, BindUploadedPetMediaInput, DeletePetProfile,
    MediaAssetDisplayMetadata, NewPetEvent, NewPetProfile, PendingPetLivePhotoUploadInput,
    PendingPetMediaUploadInput, PetRepository, ReplacePetExternalIdentifier, RestorePetProfile,
    TradePetImport, TradePetImportInput, UpdatePetProfile,
};
use maohuoban_pet_domain::pet::{
    LifecycleEventKind, PetEvent, PetExternalIdentifier, PetGuardian, PetIdentityContext,
    PetLifecycleEvent, PetMediaUploadResult, PetNameEditPolicy, PetProfile, PetResult, PetTimeline,
};
use sqlx::PgPool;
use uuid::Uuid;

mod event_queries;
mod event_rows;
mod identity_context_query;
mod lifecycle_event_repo;
mod media_commands;
mod media_metadata;
mod pet_guardian_repo;
mod profile_commands;
mod profile_create;
mod profile_crud;
mod profile_external_ids;
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

    async fn attach_profile_read_models(&self, mut pet: PetProfile) -> PetResult<PetProfile> {
        if let Some(active_microchip) = self.load_active_microchip_projection(pet.id).await? {
            pet.microchip_number = Some(active_microchip);
        }
        pet.name_edit_policy = Some(self.load_name_edit_policy(pet.id).await?);
        Ok(pet)
    }

    async fn load_active_microchip_projection(&self, pet_id: Uuid) -> PetResult<Option<String>> {
        sqlx::query_scalar::<_, String>(
            r#"
            SELECT identifier_value
            FROM pet_external_identifiers
            WHERE pet_id = $1
              AND identifier_type = 'microchip'
              AND status = 'active'
            ORDER BY created_at DESC
            LIMIT 1
            "#,
        )
        .bind(pet_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(to_infrastructure_error)
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

    async fn add_external_identifier(
        &self,
        input: AddPetExternalIdentifier,
    ) -> PetResult<PetExternalIdentifier> {
        self.add_external_identifier_command(input).await
    }

    async fn replace_external_identifier(
        &self,
        input: ReplacePetExternalIdentifier,
    ) -> PetResult<PetExternalIdentifier> {
        self.replace_external_identifier_command(input).await
    }

    async fn list_external_identifiers(
        &self,
        pet_id: Uuid,
    ) -> PetResult<Vec<PetExternalIdentifier>> {
        self.list_external_identifiers_query(pet_id).await
    }

    async fn add_guardian(&self, input: AddPetGuardian) -> PetResult<PetGuardian> {
        self.add_guardian_command(input).await
    }

    async fn list_guardians(&self, pet_id: Uuid) -> PetResult<Vec<PetGuardian>> {
        self.list_guardians_query(pet_id).await
    }

    async fn authorize_pet_access(
        &self,
        pet_id: Uuid,
        user_id: Uuid,
    ) -> PetResult<Option<PetProfile>> {
        self.authorize_pet_access_query(pet_id, user_id).await
    }

    async fn append_lifecycle_event(
        &self,
        pet_id: Uuid,
        event_kind: LifecycleEventKind,
        actor_user_id: Option<Uuid>,
        note: Option<String>,
    ) -> PetResult<PetLifecycleEvent> {
        self.append_lifecycle_event_command(pet_id, event_kind, actor_user_id, note)
            .await
    }

    async fn list_lifecycle_events(&self, pet_id: Uuid) -> PetResult<Vec<PetLifecycleEvent>> {
        self.list_lifecycle_events_query(pet_id).await
    }

    async fn load_identity_context(
        &self,
        pet_id: Uuid,
        user_id: Uuid,
    ) -> PetResult<PetIdentityContext> {
        self.load_identity_context_query(pet_id, user_id).await
    }
}
