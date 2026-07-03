use chrono::Utc;
use maohuoban_media_storage::{MediaObjectKind, MediaObjectStore, traceable_media_object_key};
use maohuoban_profile_application::profile::{
    ProfileMediaUploadDiagnostics, UploadProfileMediaInput, profile_media_content_signature,
    record_profile_media_upload,
};
use maohuoban_profile_domain::profile::{ProfileError, ProfileResult, UserProfile};
use sqlx::{Postgres, Transaction};
use uuid::Uuid;

use super::PostgresProfileRepository;
use super::helpers::{image_error_kind, sha256_hex, to_i32_dimension, to_profile_error};

impl PostgresProfileRepository {
    pub(super) async fn upload_profile_media_row(
        &self,
        input: UploadProfileMediaInput,
    ) -> ProfileResult<UserProfile> {
        let current = self
            .find_profile(input.user_id)
            .await?
            .ok_or(ProfileError::NotFound)?;
        let image = Self::decode_profile_media_image(&input)?;
        let width = to_i32_dimension(image.width())?;
        let height = to_i32_dimension(image.height())?;
        let asset_id = Uuid::new_v4();
        let media_store = Self::profile_media_store_from_env(&input, asset_id, width, height)?;
        let bucket = media_store.default_bucket().to_owned();
        let object_key = traceable_media_object_key(
            input.user_id,
            asset_id,
            Utc::now(),
            MediaObjectKind::Original {
                file_name: &input.file_name,
            },
        );
        Self::put_profile_media_object(
            &media_store,
            &input,
            asset_id,
            width,
            height,
            &bucket,
            &object_key,
        )
        .await?;

        let byte_size =
            i64::try_from(input.content.len()).map_err(|_| ProfileError::MediaTooLarge)?;
        let sha256_hex = sha256_hex(&input.content);
        let mut transaction = self
            .pool
            .begin()
            .await
            .map_err(|error| to_profile_error(&error))?;
        Self::insert_profile_media_asset(
            &mut transaction,
            &input,
            asset_id,
            &bucket,
            &object_key,
            byte_size,
            &sha256_hex,
            width,
            height,
        )
        .await?;
        Self::update_profile_media_reference(&mut transaction, &input, asset_id).await?;
        let old_asset_id = match input.kind {
            maohuoban_profile_application::profile::ProfileMediaKind::Avatar => {
                current.avatar_asset_id
            }
            maohuoban_profile_application::profile::ProfileMediaKind::Cover => {
                current.cover_asset_id
            }
        };
        if let Some(old_asset_id) = old_asset_id.filter(|old| *old != asset_id) {
            Self::queue_profile_media_cleanup(&mut transaction, old_asset_id).await?;
        }
        Self::insert_profile_media_audit_event(&mut transaction, &input, asset_id).await?;
        transaction
            .commit()
            .await
            .map_err(|error| to_profile_error(&error))?;
        record_profile_media_upload(ProfileMediaUploadDiagnostics {
            stage: "repository.committed",
            user_id: input.user_id,
            asset_id: Some(asset_id),
            kind: input.kind,
            declared_mime_type: &input.mime_type,
            byte_size,
            content_signature: Some(profile_media_content_signature(&input.content)),
            width: Some(width),
            height: Some(height),
            success: true,
            error_kind: None,
            decoder_error_kind: None,
        });

        self.find_profile(input.user_id)
            .await?
            .ok_or(ProfileError::NotFound)
    }

    fn decode_profile_media_image(
        input: &UploadProfileMediaInput,
    ) -> ProfileResult<image::DynamicImage> {
        image::load_from_memory(&input.content).map_err(|error| {
            Self::record_profile_media_repository_failure(
                input,
                None,
                "repository.decode_failed",
                None,
                None,
                "profile.media_decode_failed",
                Some(image_error_kind(&error)),
            );
            ProfileError::MediaDecodeFailed
        })
    }

    fn profile_media_store_from_env(
        input: &UploadProfileMediaInput,
        asset_id: Uuid,
        width: i32,
        height: i32,
    ) -> ProfileResult<MediaObjectStore> {
        MediaObjectStore::from_env().map_err(|error| {
            Self::record_profile_media_repository_failure(
                input,
                Some(asset_id),
                "repository.store_config",
                Some(width),
                Some(height),
                "profile.infrastructure",
                None,
            );
            ProfileError::Infrastructure(error.to_string())
        })
    }

    async fn put_profile_media_object(
        media_store: &MediaObjectStore,
        input: &UploadProfileMediaInput,
        asset_id: Uuid,
        width: i32,
        height: i32,
        bucket: &str,
        object_key: &str,
    ) -> ProfileResult<()> {
        media_store
            .put(bucket, object_key, &input.content)
            .await
            .map_err(|error| {
                Self::record_profile_media_repository_failure(
                    input,
                    Some(asset_id),
                    "repository.object_put",
                    Some(width),
                    Some(height),
                    "profile.infrastructure",
                    None,
                );
                ProfileError::Infrastructure(error.to_string())
            })
    }

    fn record_profile_media_repository_failure(
        input: &UploadProfileMediaInput,
        asset_id: Option<Uuid>,
        stage: &'static str,
        width: Option<i32>,
        height: Option<i32>,
        error_kind: &'static str,
        decoder_error_kind: Option<&'static str>,
    ) {
        record_profile_media_upload(ProfileMediaUploadDiagnostics {
            stage,
            user_id: input.user_id,
            asset_id,
            kind: input.kind,
            declared_mime_type: &input.mime_type,
            byte_size: i64::try_from(input.content.len()).unwrap_or(i64::MAX),
            content_signature: Some(profile_media_content_signature(&input.content)),
            width,
            height,
            success: false,
            error_kind: Some(error_kind),
            decoder_error_kind,
        });
    }

    #[allow(clippy::too_many_arguments)]
    async fn insert_profile_media_asset(
        transaction: &mut Transaction<'_, Postgres>,
        input: &UploadProfileMediaInput,
        asset_id: Uuid,
        bucket: &str,
        object_key: &str,
        byte_size: i64,
        sha256_hex: &str,
        width: i32,
        height: i32,
    ) -> ProfileResult<()> {
        sqlx::query(
            r"
            INSERT INTO media_assets (
                id,
                uploaded_by_user_id,
                owner_pet_id,
                usage_kind,
                source_client,
                original_file_name,
                mime_type,
                byte_size,
                sha256_hex,
                bucket,
                object_key,
                status,
                width,
                height
            )
            VALUES ($1, $2, NULL, $3, $4, $5, $6, $7, $8, $9, $10, 'bound', $11, $12)
            ",
        )
        .bind(asset_id)
        .bind(input.user_id)
        .bind(input.kind.usage_kind())
        .bind(input.source_client.as_deref())
        .bind(&input.file_name)
        .bind(&input.mime_type)
        .bind(byte_size)
        .bind(sha256_hex)
        .bind(bucket)
        .bind(object_key)
        .bind(width)
        .bind(height)
        .execute(&mut **transaction)
        .await
        .map_err(|error| to_profile_error(&error))?;
        Ok(())
    }

    async fn update_profile_media_reference(
        transaction: &mut Transaction<'_, Postgres>,
        input: &UploadProfileMediaInput,
        asset_id: Uuid,
    ) -> ProfileResult<()> {
        let query = match input.kind {
            maohuoban_profile_application::profile::ProfileMediaKind::Avatar => {
                "UPDATE user_profiles SET avatar_asset_id = $2, updated_at = now() WHERE user_id = $1"
            }
            maohuoban_profile_application::profile::ProfileMediaKind::Cover => {
                "UPDATE user_profiles SET cover_asset_id = $2, updated_at = now() WHERE user_id = $1"
            }
        };
        sqlx::query(query)
            .bind(input.user_id)
            .bind(asset_id)
            .execute(&mut **transaction)
            .await
            .map_err(|error| to_profile_error(&error))?;
        Ok(())
    }

    async fn queue_profile_media_cleanup(
        transaction: &mut Transaction<'_, Postgres>,
        old_asset_id: Uuid,
    ) -> ProfileResult<()> {
        sqlx::query(
            r"
            UPDATE media_assets
            SET status = 'cleanup_pending',
                delete_after = now() + interval '7 days',
                updated_at = now()
            WHERE id = $1
              AND status <> 'deleted'
            ",
        )
        .bind(old_asset_id)
        .execute(&mut **transaction)
        .await
        .map_err(|error| to_profile_error(&error))?;

        sqlx::query(
            r"
            INSERT INTO media_cleanup_jobs (id, asset_id, run_after)
            VALUES ($1, $2, now() + interval '7 days')
            ",
        )
        .bind(Uuid::new_v4())
        .bind(old_asset_id)
        .execute(&mut **transaction)
        .await
        .map_err(|error| to_profile_error(&error))?;
        Ok(())
    }

    async fn insert_profile_media_audit_event(
        transaction: &mut Transaction<'_, Postgres>,
        input: &UploadProfileMediaInput,
        asset_id: Uuid,
    ) -> ProfileResult<()> {
        sqlx::query(
            r"
            INSERT INTO media_audit_events (
                id,
                asset_id,
                actor_user_id,
                event_kind,
                event_payload
            )
            VALUES ($1, $2, $3, 'uploaded', $4)
            ",
        )
        .bind(Uuid::new_v4())
        .bind(asset_id)
        .bind(input.user_id)
        .bind(serde_json::json!({
            "usage_kind": input.kind.usage_kind(),
            "source_client": input.source_client
        }))
        .execute(&mut **transaction)
        .await
        .map_err(|error| to_profile_error(&error))?;
        Ok(())
    }
}
