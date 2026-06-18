use maohuoban_pet_domain::pet::{MediaUsageKind, PetBackgroundMediaKind, PetResult};
use sqlx::{Postgres, Transaction};
use uuid::Uuid;

use crate::postgres::repository::PostgresPetRepository;
use crate::postgres::repository::rows::{
    MediaAssetComponentRow, MediaBindingRow, MediaDerivativeRow,
};
use crate::postgres::repository::storage::to_infrastructure_error;

impl PostgresPetRepository {
    pub(super) async fn insert_media_binding_for_asset(
        transaction: &mut Transaction<'_, Postgres>,
        asset_id: Uuid,
        pet_id: Uuid,
        owner_user_id: Uuid,
        usage_kind: MediaUsageKind,
    ) -> PetResult<MediaBindingRow> {
        sqlx::query_as::<_, MediaBindingRow>(
            r#"
            INSERT INTO media_bindings (
                id,
                asset_id,
                pet_id,
                usage_kind,
                status,
                bound_by_user_id
            )
            VALUES ($1, $2, $3, $4, 'active', $5)
            RETURNING
                id,
                asset_id,
                pet_id,
                usage_kind,
                status,
                bound_by_user_id,
                bound_at,
                replaced_at,
                created_at
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(asset_id)
        .bind(pet_id)
        .bind(usage_kind.as_str())
        .bind(owner_user_id)
        .fetch_one(&mut **transaction)
        .await
        .map_err(to_infrastructure_error)
    }

    pub(super) async fn update_pet_media_reference_by_usage(
        transaction: &mut Transaction<'_, Postgres>,
        pet_id: Uuid,
        owner_user_id: Uuid,
        asset_id: Uuid,
        usage_kind: MediaUsageKind,
    ) -> PetResult<()> {
        let (avatar_asset_id, background_asset_id, background_media_kind) = match usage_kind {
            MediaUsageKind::PetAvatar => (Some(asset_id), None, None),
            MediaUsageKind::PetBackgroundImage => (
                None,
                Some(asset_id),
                Some(PetBackgroundMediaKind::Image.as_str()),
            ),
            MediaUsageKind::PetBackgroundVideo => (
                None,
                Some(asset_id),
                Some(PetBackgroundMediaKind::Video.as_str()),
            ),
            MediaUsageKind::PetBackgroundLivePhoto => (
                None,
                Some(asset_id),
                Some(PetBackgroundMediaKind::LivePhoto.as_str()),
            ),
        };
        sqlx::query(
            r#"
            UPDATE pet_profiles
            SET
                avatar_asset_id = COALESCE($3, avatar_asset_id),
                background_asset_id = COALESCE($4, background_asset_id),
                background_media_kind = COALESCE($5, background_media_kind),
                updated_at = now()
            WHERE id = $1 AND owner_user_id = $2 AND deleted_at IS NULL
            "#,
        )
        .bind(pet_id)
        .bind(owner_user_id)
        .bind(avatar_asset_id)
        .bind(background_asset_id)
        .bind(background_media_kind)
        .execute(&mut **transaction)
        .await
        .map_err(to_infrastructure_error)?;

        Ok(())
    }

    pub(super) async fn insert_bound_audit_event_for_asset(
        transaction: &mut Transaction<'_, Postgres>,
        pet_id: Uuid,
        owner_user_id: Uuid,
        asset_id: Uuid,
        usage_kind: MediaUsageKind,
    ) -> PetResult<()> {
        sqlx::query(
            r#"
            INSERT INTO media_audit_events (
                id,
                asset_id,
                pet_id,
                actor_user_id,
                event_kind,
                event_payload
            )
            VALUES ($1, $2, $3, $4, 'bound', $5)
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(asset_id)
        .bind(pet_id)
        .bind(owner_user_id)
        .bind(serde_json::json!({ "usage_kind": usage_kind.as_str() }))
        .execute(&mut **transaction)
        .await
        .map_err(to_infrastructure_error)?;

        Ok(())
    }

    pub(super) async fn select_media_derivatives(
        transaction: &mut Transaction<'_, Postgres>,
        asset_id: Uuid,
    ) -> PetResult<Vec<MediaDerivativeRow>> {
        sqlx::query_as::<_, MediaDerivativeRow>(
            r#"
            SELECT
                id,
                parent_asset_id,
                derivative_kind,
                bucket,
                object_key,
                mime_type,
                byte_size,
                sha256_hex,
                metadata,
                created_at
            FROM media_derivatives
            WHERE parent_asset_id = $1
            ORDER BY created_at ASC
            "#,
        )
        .bind(asset_id)
        .fetch_all(&mut **transaction)
        .await
        .map_err(to_infrastructure_error)
    }

    pub(super) async fn select_media_asset_components(
        transaction: &mut Transaction<'_, Postgres>,
        asset_id: Uuid,
    ) -> PetResult<Vec<MediaAssetComponentRow>> {
        sqlx::query_as::<_, MediaAssetComponentRow>(
            r#"
            SELECT
                id,
                asset_id,
                component_kind,
                bucket,
                object_key,
                mime_type,
                byte_size,
                sha256_hex,
                width,
                height,
                duration_ms,
                created_at
            FROM media_asset_components
            WHERE asset_id = $1
            ORDER BY created_at ASC
            "#,
        )
        .bind(asset_id)
        .fetch_all(&mut **transaction)
        .await
        .map_err(to_infrastructure_error)
    }
}
