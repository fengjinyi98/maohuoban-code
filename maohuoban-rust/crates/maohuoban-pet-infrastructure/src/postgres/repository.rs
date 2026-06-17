use async_trait::async_trait;
use chrono::{DateTime, Duration, Utc};
use maohuoban_pet_application::pet::{
    BindUploadedPetMediaInput, DeletePetProfile, MediaAssetDisplayMetadata, NewPetEvent,
    NewPetProfile, PendingPetMediaUploadInput, PetRepository, RestorePetProfile, TradePetImport,
    TradePetImportInput, UpdatePetProfile,
};
use maohuoban_pet_domain::pet::{
    PetError, PetEvent, PetMediaUploadResult, PetNameEditPolicy, PetNeuterStatus, PetProfile,
    PetResult, PetSex, PetSpecies, PetTimeline,
};
use sqlx::{FromRow, PgPool};
use uuid::Uuid;

mod media_commands;
mod profile_commands;
mod profile_queries;
mod rows;
mod storage;
mod trade_import;

use profile_queries::load_pet_profile_for_update;
use rows::{PetEventRow, PetProfileRow};
use storage::{profile_number_from_uuid, to_infrastructure_error};
use trade_import::{insert_trade_import_event, insert_trade_import_pet};

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

/// MediaAssetDisplayMetadataRow 媒体展示元数据行
/// 核心职责：
/// - 聚合媒体资产尺寸字段
/// - 读取主题色派生物元数据
#[derive(Debug, FromRow)]
struct MediaAssetDisplayMetadataRow {
    asset_id: Uuid,
    width: Option<i32>,
    height: Option<i32>,
    theme_color_hex: Option<String>,
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

    PetNameEditPolicy {
        max_count: NAME_EDIT_MAX_COUNT,
        used_count,
        remaining_count,
        window_days: NAME_EDIT_WINDOW_DAYS,
        window_ends_at,
        display_text: format!(
            "{NAME_EDIT_WINDOW_DAYS} 天内可修改 {NAME_EDIT_MAX_COUNT} 次名字，本周期还可修改 {remaining_count} 次。"
        ),
    }
}

#[async_trait]
#[allow(clippy::too_many_lines)]
impl PetRepository for PostgresPetRepository {
    async fn create_pet_profile(&self, input: NewPetProfile) -> PetResult<PetProfile> {
        let pet_id = Uuid::new_v4();
        let mut transaction = self.pool.begin().await.map_err(to_infrastructure_error)?;
        let row = sqlx::query_as::<_, PetProfileRow>(
            r#"
            INSERT INTO pet_profiles (
                id,
                owner_user_id,
                name,
                species,
                breed,
                sex,
                birthday,
                profile_number,
                microchip_number,
                arrival_date,
                weight_grams,
                neuter_status,
                personality_tags,
                note,
                managed_status,
                source_kind
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, 'family', $15)
            RETURNING
                id,
                owner_user_id,
                merchant_id,
                name,
                species,
                breed,
                sex,
                birthday,
                profile_number,
                microchip_number,
                arrival_date,
                weight_grams,
                neuter_status,
                personality_tags,
                note,
                avatar_asset_id,
                background_asset_id,
                background_media_kind,
                deleted_at,
                delete_requested_by_user_id,
                recoverable_until,
                delete_reason,
                managed_status,
                source_kind,
                created_at,
                updated_at
            "#,
        )
        .bind(pet_id)
        .bind(input.owner_user_id)
        .bind(input.name)
        .bind(input.species.as_str())
        .bind(input.breed)
        .bind(input.sex.as_str())
        .bind(input.birthday)
        .bind(profile_number_from_uuid(pet_id))
        .bind(input.microchip_number)
        .bind(input.arrival_date)
        .bind(input.weight_grams)
        .bind(input.neuter_status.as_str())
        .bind(serde_json::json!(input.personality_tags))
        .bind(input.note)
        .bind(input.source_kind.as_str())
        .fetch_one(&mut *transaction)
        .await
        .map_err(to_infrastructure_error)?;

        let has_media_assets =
            input.avatar_asset_id.is_some() || input.background_asset_id.is_some();
        if let Some(asset_id) = input.avatar_asset_id {
            Self::bind_uploaded_media_in_transaction(
                &mut transaction,
                pet_id,
                input.owner_user_id,
                asset_id,
            )
            .await?;
        }
        if let Some(asset_id) = input.background_asset_id {
            Self::bind_uploaded_media_in_transaction(
                &mut transaction,
                pet_id,
                input.owner_user_id,
                asset_id,
            )
            .await?;
        }

        let pet = row.try_into()?;
        transaction
            .commit()
            .await
            .map_err(to_infrastructure_error)?;

        let pet = if has_media_assets {
            self.find_pet_for_owner(pet_id, input.owner_user_id)
                .await?
                .ok_or(PetError::PetNotFound)?
        } else {
            pet
        };

        self.attach_name_edit_policy(pet).await
    }

    async fn find_pet_for_owner(
        &self,
        pet_id: Uuid,
        owner_user_id: Uuid,
    ) -> PetResult<Option<PetProfile>> {
        let row = sqlx::query_as::<_, PetProfileRow>(
            r#"
            SELECT
                id,
                owner_user_id,
                merchant_id,
                name,
                species,
                breed,
                sex,
                birthday,
                profile_number,
                microchip_number,
                arrival_date,
                weight_grams,
                neuter_status,
                personality_tags,
                note,
                avatar_asset_id,
                background_asset_id,
                background_media_kind,
                deleted_at,
                delete_requested_by_user_id,
                recoverable_until,
                delete_reason,
                managed_status,
                source_kind,
                created_at,
                updated_at
            FROM pet_profiles
            WHERE id = $1 AND owner_user_id = $2 AND deleted_at IS NULL
            "#,
        )
        .bind(pet_id)
        .bind(owner_user_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        let Some(row) = row else {
            return Ok(None);
        };
        let pet = row.try_into()?;
        Ok(Some(self.attach_name_edit_policy(pet).await?))
    }

    async fn list_pet_profiles_for_owner(&self, owner_user_id: Uuid) -> PetResult<Vec<PetProfile>> {
        let rows = sqlx::query_as::<_, PetProfileRow>(
            r#"
            SELECT
                id,
                owner_user_id,
                merchant_id,
                name,
                species,
                breed,
                sex,
                birthday,
                profile_number,
                microchip_number,
                arrival_date,
                weight_grams,
                neuter_status,
                personality_tags,
                note,
                avatar_asset_id,
                background_asset_id,
                background_media_kind,
                deleted_at,
                delete_requested_by_user_id,
                recoverable_until,
                delete_reason,
                managed_status,
                source_kind,
                created_at,
                updated_at
            FROM pet_profiles
            WHERE owner_user_id = $1 AND deleted_at IS NULL
            ORDER BY created_at ASC
            "#,
        )
        .bind(owner_user_id)
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        let mut pets = Vec::with_capacity(rows.len());
        for row in rows {
            pets.push(self.attach_name_edit_policy(row.try_into()?).await?);
        }
        Ok(pets)
    }

    async fn update_pet_profile(&self, input: UpdatePetProfile) -> PetResult<PetProfile> {
        let current = load_pet_profile_for_update(&self.pool, input.pet_id, input.owner_user_id)
            .await?
            .ok_or(PetError::PetNotFound)?;
        let requested_microchip = input.microchip_number.as_deref().map(str::trim);
        let requested_name = input.name.as_deref().map(str::trim).map(str::to_owned);
        let is_name_changed = requested_name
            .as_deref()
            .is_some_and(|name| name != current.name);
        if is_name_changed {
            let policy = self.load_name_edit_policy(input.pet_id).await?;
            if policy.remaining_count <= 0 {
                return Err(PetError::NameEditLimitExceeded);
            }
        }
        if let (Some(existing), Some(requested)) =
            (current.microchip_number.as_deref(), requested_microchip)
            && existing != requested
        {
            return Err(PetError::InvalidInput(
                "芯片号已锁定，如需变更请通过申诉渠道处理".to_owned(),
            ));
        }

        let row = sqlx::query_as::<_, PetProfileRow>(
            r#"
            UPDATE pet_profiles
            SET
                name = COALESCE($3, name),
                species = COALESCE($4, species),
                breed = COALESCE($5, breed),
                sex = COALESCE($6, sex),
                birthday = COALESCE($7, birthday),
                microchip_number = COALESCE($8, microchip_number),
                arrival_date = COALESCE($9, arrival_date),
                weight_grams = COALESCE($10, weight_grams),
                neuter_status = COALESCE($11, neuter_status),
                personality_tags = COALESCE($12, personality_tags),
                note = COALESCE($13, note),
                updated_at = now()
            WHERE id = $1 AND owner_user_id = $2 AND deleted_at IS NULL
            RETURNING
                id,
                owner_user_id,
                merchant_id,
                name,
                species,
                breed,
                sex,
                birthday,
                profile_number,
                microchip_number,
                arrival_date,
                weight_grams,
                neuter_status,
                personality_tags,
                note,
                avatar_asset_id,
                background_asset_id,
                background_media_kind,
                deleted_at,
                delete_requested_by_user_id,
                recoverable_until,
                delete_reason,
                managed_status,
                source_kind,
                created_at,
                updated_at
            "#,
        )
        .bind(input.pet_id)
        .bind(input.owner_user_id)
        .bind(requested_name.as_deref())
        .bind(input.species.map(PetSpecies::as_str))
        .bind(input.breed)
        .bind(input.sex.map(PetSex::as_str))
        .bind(input.birthday)
        .bind(requested_microchip.map(str::to_owned))
        .bind(input.arrival_date)
        .bind(input.weight_grams)
        .bind(input.neuter_status.map(PetNeuterStatus::as_str))
        .bind(input.personality_tags.map(|tags| serde_json::json!(tags)))
        .bind(input.note)
        .fetch_optional(&self.pool)
        .await
        .map_err(to_infrastructure_error)?
        .ok_or(PetError::PetNotFound)?;

        if is_name_changed && let Some(new_name) = requested_name.as_deref() {
            self.record_name_change(input.pet_id, input.owner_user_id, &current.name, new_name)
                .await?;
        }

        self.attach_name_edit_policy(row.try_into()?).await
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
        if asset_ids.is_empty() {
            return Ok(Vec::new());
        }

        let rows = sqlx::query_as::<_, MediaAssetDisplayMetadataRow>(
            r#"
            SELECT
                asset.id AS asset_id,
                asset.width,
                asset.height,
                derivative.metadata ->> 'theme_color_hex' AS theme_color_hex
            FROM media_assets asset
            LEFT JOIN media_derivatives derivative
                ON derivative.parent_asset_id = asset.id
                AND derivative.derivative_kind = 'theme_color_frame'
            WHERE asset.id = ANY($1)
              AND asset.deleted_at IS NULL
              AND asset.status IN ('uploaded', 'bound')
            "#,
        )
        .bind(asset_ids)
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        Ok(rows
            .into_iter()
            .map(|row| MediaAssetDisplayMetadata {
                asset_id: row.asset_id,
                width: row.width,
                height: row.height,
                theme_color_hex: row.theme_color_hex,
            })
            .collect())
    }

    async fn create_pet_event(&self, input: NewPetEvent) -> PetResult<PetEvent> {
        let event_id = Uuid::new_v4();
        let row = sqlx::query_as::<_, PetEventRow>(
            r#"
            INSERT INTO pet_events (
                id,
                pet_id,
                event_kind,
                event_subkind,
                title,
                summary,
                visibility,
                event_payload,
                occurred_at,
                actor_user_id,
                record_revision
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 1)
            RETURNING
                id,
                pet_id,
                litter_id,
                event_kind,
                event_subkind,
                title,
                summary,
                visibility,
                event_payload,
                occurred_at,
                actor_user_id,
                evidence_snapshot_id,
                record_revision,
                created_at,
                updated_at
            "#,
        )
        .bind(event_id)
        .bind(input.pet_id)
        .bind(input.event_kind.as_str())
        .bind(input.event_subkind)
        .bind(input.title)
        .bind(input.summary)
        .bind(input.visibility.as_str())
        .bind(input.event_payload)
        .bind(input.occurred_at)
        .bind(input.actor_user_id)
        .fetch_one(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        row.try_into()
    }

    async fn import_trade_pet(&self, input: TradePetImportInput) -> PetResult<TradePetImport> {
        let mut transaction = self.pool.begin().await.map_err(to_infrastructure_error)?;
        let pet_id = Uuid::new_v4();
        let pet_row = insert_trade_import_pet(&mut transaction, pet_id, &input).await?;
        let event_row = insert_trade_import_event(&mut transaction, pet_id, &input).await?;

        transaction
            .commit()
            .await
            .map_err(to_infrastructure_error)?;

        Ok(TradePetImport {
            pet: pet_row.try_into()?,
            event: event_row.try_into()?,
        })
    }

    async fn load_pet_timeline(
        &self,
        owner_user_id: Uuid,
        pet_id: Uuid,
        limit: i64,
    ) -> PetResult<PetTimeline> {
        let rows = sqlx::query_as::<_, PetEventRow>(
            r#"
            SELECT
                e.id,
                e.pet_id,
                e.litter_id,
                e.event_kind,
                e.event_subkind,
                e.title,
                e.summary,
                e.visibility,
                e.event_payload,
                e.occurred_at,
                e.actor_user_id,
                e.evidence_snapshot_id,
                e.record_revision,
                e.created_at,
                e.updated_at
            FROM pet_events e
            INNER JOIN pet_profiles p ON p.id = e.pet_id
            WHERE e.pet_id = $1 AND p.owner_user_id = $2
            ORDER BY e.occurred_at DESC, e.created_at DESC
            LIMIT $3
            "#,
        )
        .bind(pet_id)
        .bind(owner_user_id)
        .bind(limit)
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        let events = rows
            .into_iter()
            .map(TryInto::try_into)
            .collect::<PetResult<Vec<_>>>()?;
        Ok(PetTimeline { pet_id, events })
    }

    async fn load_pet_event_detail(
        &self,
        owner_user_id: Uuid,
        event_id: Uuid,
    ) -> PetResult<Option<PetEvent>> {
        let row = sqlx::query_as::<_, PetEventRow>(
            r#"
            SELECT
                e.id,
                e.pet_id,
                e.litter_id,
                e.event_kind,
                e.event_subkind,
                e.title,
                e.summary,
                e.visibility,
                e.event_payload,
                e.occurred_at,
                e.actor_user_id,
                e.evidence_snapshot_id,
                e.record_revision,
                e.created_at,
                e.updated_at
            FROM pet_events e
            LEFT JOIN pet_profiles p ON p.id = e.pet_id
            LEFT JOIN litters l ON l.id = e.litter_id
            LEFT JOIN merchant_profiles merchant
                ON merchant.id = COALESCE(p.merchant_id, l.merchant_id)
            WHERE e.id = $1
                AND (
                    p.owner_user_id = $2
                    OR e.actor_user_id = $2
                    OR (
                        merchant.owner_user_id = $2
                        AND merchant.verification_status = 'verified'
                    )
                )
            "#,
        )
        .bind(event_id)
        .bind(owner_user_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        row.map(TryInto::try_into).transpose()
    }
}
