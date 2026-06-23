use async_trait::async_trait;
use chrono::{DateTime, Datelike, Duration, Utc};
use maohuoban_media_storage::MediaObjectStore;
use maohuoban_profile_application::profile::{
    DefaultProfileInput, ProfileMediaUploadDiagnostics, ProfileRepository as ProfileRepositoryPort,
    UpdateProfileInput, UploadProfileMediaInput, profile_media_content_signature,
    record_profile_media_upload,
};
use maohuoban_profile_domain::profile::{
    ProfileError, ProfileFieldEditPolicy, ProfileMediaAsset, ProfileResult, UserProfile,
};
use sha2::{Digest, Sha256};
use sqlx::{PgPool, Postgres, Transaction};
use uuid::Uuid;

mod rows;

use rows::{ProfileMediaAssetRow, UserProfileRow};

const DISPLAY_NAME_EDIT_MAX_COUNT: i32 = 5;
const BIO_EDIT_MAX_COUNT: i32 = 3;
const PROFILE_FIELD_EDIT_WINDOW_DAYS: i32 = 30;

/// `PostgresProfileRepository` `PostgreSQL` 用户资料仓库
/// 核心职责：
/// - 持久化用户资料和默认资料生成结果
/// - 通过唯一索引保证用户资料和毛伙伴号唯一
#[derive(Debug, Clone)]
pub struct PostgresProfileRepository {
    pool: PgPool,
}

impl PostgresProfileRepository {
    #[must_use]
    pub const fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    async fn find_profile(&self, user_id: Uuid) -> ProfileResult<Option<UserProfile>> {
        let profile = sqlx::query_as::<_, UserProfileRow>(
            r"
            SELECT
                user_id,
                maohuoban_id,
                display_name,
                default_display_name,
                bio,
                gender,
                is_gender_visible,
                birthday,
                avatar_asset_id,
                cover_asset_id
            FROM user_profiles
            WHERE user_id = $1
            ",
        )
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|error| to_profile_error(&error))?
        .map(Into::into);

        match profile {
            Some(profile) => {
                let profile = self.attach_media_assets(profile).await?;
                Ok(Some(self.attach_edit_policies(profile).await?))
            }
            None => Ok(None),
        }
    }

    async fn attach_media_assets(&self, mut profile: UserProfile) -> ProfileResult<UserProfile> {
        if let Some(asset_id) = profile.avatar_asset_id {
            profile.avatar = self.load_profile_media_asset(asset_id).await?;
        }
        if let Some(asset_id) = profile.cover_asset_id {
            profile.cover = self.load_profile_media_asset(asset_id).await?;
        }
        Ok(profile)
    }

    async fn load_profile_media_asset(
        &self,
        asset_id: Uuid,
    ) -> ProfileResult<Option<ProfileMediaAsset>> {
        sqlx::query_as::<_, ProfileMediaAssetRow>(
            r"
            SELECT id, mime_type, width, height, updated_at
            FROM media_assets
            WHERE id = $1
              AND deleted_at IS NULL
              AND status IN ('uploaded', 'bound')
            ",
        )
        .bind(asset_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|error| to_profile_error(&error))
        .map(|row| row.map(Into::into))
    }

    async fn attach_edit_policies(&self, mut profile: UserProfile) -> ProfileResult<UserProfile> {
        profile.display_name_edit_policy = Some(
            self.load_field_edit_policy(
                profile.user_id,
                "display_name",
                DISPLAY_NAME_EDIT_MAX_COUNT,
                "昵称",
            )
            .await?,
        );
        profile.bio_edit_policy = Some(
            self.load_field_edit_policy(profile.user_id, "bio", BIO_EDIT_MAX_COUNT, "简介")
                .await?,
        );
        Ok(profile)
    }

    async fn load_field_edit_policy(
        &self,
        user_id: Uuid,
        field_name: &str,
        max_count: i32,
        display_name: &str,
    ) -> ProfileResult<ProfileFieldEditPolicy> {
        let (used_count, first_changed_at) = sqlx::query_as::<_, (i64, Option<DateTime<Utc>>)>(
            r"
            SELECT COUNT(*) AS used_count, MIN(changed_at) AS first_changed_at
            FROM user_profile_field_changes
            WHERE user_id = $1
              AND field_name = $2
              AND changed_at >= now() - interval '30 days'
            ",
        )
        .bind(user_id)
        .bind(field_name)
        .fetch_one(&self.pool)
        .await
        .map_err(|error| to_profile_error(&error))?;

        Ok(profile_field_edit_policy(
            used_count,
            first_changed_at,
            max_count,
            display_name,
        ))
    }

    async fn record_field_change(
        &self,
        user_id: Uuid,
        field_name: &str,
        old_value: Option<&str>,
        new_value: &str,
    ) -> ProfileResult<()> {
        sqlx::query(
            r"
            INSERT INTO user_profile_field_changes (
                id,
                user_id,
                field_name,
                old_value,
                new_value
            )
            VALUES ($1, $2, $3, $4, $5)
            ",
        )
        .bind(Uuid::new_v4())
        .bind(user_id)
        .bind(field_name)
        .bind(old_value)
        .bind(new_value)
        .execute(&self.pool)
        .await
        .map_err(|error| to_profile_error(&error))?;

        Ok(())
    }

    async fn insert_default_profile(
        &self,
        input: DefaultProfileInput,
    ) -> ProfileResult<UserProfile> {
        let maohuoban_id = generate_maohuoban_id();
        let default_display_name = format!(
            "毛伙伴用户{}",
            maohuoban_id
                .chars()
                .rev()
                .take(5)
                .collect::<String>()
                .chars()
                .rev()
                .collect::<String>()
        );

        let profile = sqlx::query_as::<_, UserProfileRow>(
            r"
            INSERT INTO user_profiles (
                user_id,
                maohuoban_id,
                display_name,
                default_display_name,
                gender,
                is_gender_visible
            )
            VALUES ($1, $2, $3, $3, 'unknown', true)
            ON CONFLICT (user_id) DO UPDATE
            SET updated_at = user_profiles.updated_at
            RETURNING
                user_id,
                maohuoban_id,
                display_name,
                default_display_name,
                bio,
                gender,
                is_gender_visible,
                birthday,
                avatar_asset_id,
                cover_asset_id
            ",
        )
        .bind(input.user_id)
        .bind(maohuoban_id)
        .bind(default_display_name)
        .fetch_one(&self.pool)
        .await
        .map_err(|error| to_profile_error(&error))
        .map(Into::into)?;

        self.attach_edit_policies(profile).await
    }

    async fn update_profile_row(&self, input: UpdateProfileInput) -> ProfileResult<UserProfile> {
        let current = self
            .find_profile(input.user_id)
            .await?
            .ok_or(ProfileError::NotFound)?;
        let requested_display_name = input.display_name.clone();
        let requested_bio = input.bio.clone();
        let is_display_name_changed = requested_display_name
            .as_deref()
            .is_some_and(|display_name| display_name != current.display_name);
        let is_bio_changed = requested_bio
            .as_deref()
            .is_some_and(|bio| current.bio.as_deref() != Some(bio));

        if is_display_name_changed {
            let policy = current.display_name_edit_policy.as_ref().ok_or_else(|| {
                ProfileError::Infrastructure("missing display name policy".into())
            })?;
            if policy.remaining_count <= 0 {
                return Err(ProfileError::DisplayNameEditLimitExceeded);
            }
        }
        if is_bio_changed {
            let policy = current
                .bio_edit_policy
                .as_ref()
                .ok_or_else(|| ProfileError::Infrastructure("missing bio policy".into()))?;
            if policy.remaining_count <= 0 {
                return Err(ProfileError::BioEditLimitExceeded);
            }
        }

        let gender = input.gender.map(|gender| gender.as_str().to_owned());

        let profile = sqlx::query_as::<_, UserProfileRow>(
            r"
            UPDATE user_profiles
            SET
                display_name = COALESCE($2, display_name),
                bio = COALESCE($3, bio),
                gender = COALESCE($4, gender),
                is_gender_visible = COALESCE($5, is_gender_visible),
                birthday = COALESCE($6, birthday),
                updated_at = now()
            WHERE user_id = $1
            RETURNING
                user_id,
                maohuoban_id,
                display_name,
                default_display_name,
                bio,
                gender,
                is_gender_visible,
                birthday,
                avatar_asset_id,
                cover_asset_id
            ",
        )
        .bind(input.user_id)
        .bind(input.display_name)
        .bind(input.bio)
        .bind(gender)
        .bind(input.is_gender_visible)
        .bind(input.birthday)
        .fetch_optional(&self.pool)
        .await
        .map_err(|error| to_profile_error(&error))?
        .map(Into::into)
        .ok_or(ProfileError::NotFound)?;

        if is_display_name_changed && let Some(new_display_name) = requested_display_name.as_deref()
        {
            self.record_field_change(
                input.user_id,
                "display_name",
                Some(&current.display_name),
                new_display_name,
            )
            .await?;
        }
        if is_bio_changed && let Some(new_bio) = requested_bio.as_deref() {
            self.record_field_change(input.user_id, "bio", current.bio.as_deref(), new_bio)
                .await?;
        }

        self.attach_edit_policies(profile).await
    }

    async fn upload_profile_media_row(
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
        let object_key = format!(
            "users/{}/profile/{}/{}/{}",
            input.user_id,
            input.kind.path_segment(),
            asset_id,
            sanitized_file_name(&input.file_name)
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
        if let Some(old_asset_id) = old_asset_id.filter(|old_asset_id| *old_asset_id != asset_id) {
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

fn profile_field_edit_policy(
    used_count: i64,
    first_changed_at: Option<DateTime<Utc>>,
    max_count: i32,
    display_name: &str,
) -> ProfileFieldEditPolicy {
    let used_count = i32::try_from(used_count).unwrap_or(i32::MAX);
    let remaining_count = max_count.saturating_sub(used_count).max(0);
    let window_ends_at = first_changed_at
        .map(|changed_at| changed_at + Duration::days(i64::from(PROFILE_FIELD_EDIT_WINDOW_DAYS)));
    let display_text = window_ends_at.map_or_else(
        || format!("{PROFILE_FIELD_EDIT_WINDOW_DAYS} 天内最多修改 {max_count} 次{display_name}。"),
        |ends_at| {
            format!(
                "{}月{}日前还可以修改 {remaining_count} 次{display_name}。",
                ends_at.month(),
                ends_at.day()
            )
        },
    );

    ProfileFieldEditPolicy {
        max_count,
        used_count,
        remaining_count,
        window_days: PROFILE_FIELD_EDIT_WINDOW_DAYS,
        window_ends_at,
        display_text,
    }
}

#[async_trait]
impl ProfileRepositoryPort for PostgresProfileRepository {
    async fn find_by_user_id(&self, user_id: Uuid) -> ProfileResult<Option<UserProfile>> {
        self.find_profile(user_id).await
    }

    async fn create_default_profile(
        &self,
        input: DefaultProfileInput,
    ) -> ProfileResult<UserProfile> {
        self.insert_default_profile(input).await
    }

    async fn update_profile(&self, input: UpdateProfileInput) -> ProfileResult<UserProfile> {
        self.update_profile_row(input).await
    }

    async fn upload_profile_media(
        &self,
        input: UploadProfileMediaInput,
    ) -> ProfileResult<UserProfile> {
        self.upload_profile_media_row(input).await
    }
}

fn generate_maohuoban_id() -> String {
    Uuid::new_v4()
        .simple()
        .to_string()
        .chars()
        .take(12)
        .map(|character| character.to_ascii_uppercase())
        .collect()
}

fn to_profile_error(error: &sqlx::Error) -> ProfileError {
    ProfileError::Infrastructure(error.to_string())
}

fn sha256_hex(content: &[u8]) -> String {
    let digest = Sha256::digest(content);
    digest.iter().fold(String::new(), |mut output, byte| {
        use std::fmt::Write as _;
        write!(&mut output, "{byte:02x}").expect("write sha256 hex");
        output
    })
}

fn sanitized_file_name(file_name: &str) -> String {
    let sanitized = file_name
        .chars()
        .map(|character| {
            if character.is_ascii_alphanumeric() || matches!(character, '.' | '-' | '_') {
                character
            } else {
                '_'
            }
        })
        .collect::<String>();
    if sanitized.is_empty() {
        Uuid::new_v4().to_string()
    } else {
        sanitized
    }
}

fn to_i32_dimension(value: u32) -> ProfileResult<i32> {
    i32::try_from(value)
        .ok()
        .filter(|value| *value > 0)
        .ok_or(ProfileError::MediaDecodeFailed)
}

fn image_error_kind(error: &image::ImageError) -> &'static str {
    match error {
        image::ImageError::Decoding(_) => "decoding",
        image::ImageError::Encoding(_) => "encoding",
        image::ImageError::Parameter(_) => "parameter",
        image::ImageError::Limits(_) => "limits",
        image::ImageError::Unsupported(_) => "unsupported",
        image::ImageError::IoError(_) => "io",
    }
}
