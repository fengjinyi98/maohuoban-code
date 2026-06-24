use chrono::{DateTime, Utc};
use maohuoban_profile_domain::profile::{
    ProfileFieldEditPolicy, ProfileMediaAsset, ProfileResult, UserProfile,
};
use uuid::Uuid;

use super::helpers::{profile_field_edit_policy, to_profile_error};
use super::rows::{ProfileMediaAssetRow, UserProfileRow};
use super::{BIO_EDIT_MAX_COUNT, DISPLAY_NAME_EDIT_MAX_COUNT, PostgresProfileRepository};

impl PostgresProfileRepository {
    pub(super) async fn find_profile(&self, user_id: Uuid) -> ProfileResult<Option<UserProfile>> {
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

    pub(super) async fn attach_media_assets(
        &self,
        mut profile: UserProfile,
    ) -> ProfileResult<UserProfile> {
        if let Some(asset_id) = profile.avatar_asset_id {
            profile.avatar = self.load_profile_media_asset(asset_id).await?;
        }
        if let Some(asset_id) = profile.cover_asset_id {
            profile.cover = self.load_profile_media_asset(asset_id).await?;
        }
        Ok(profile)
    }

    pub(super) async fn load_profile_media_asset(
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

    pub(super) async fn attach_edit_policies(
        &self,
        mut profile: UserProfile,
    ) -> ProfileResult<UserProfile> {
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

    pub(super) async fn load_field_edit_policy(
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

    pub(super) async fn record_field_change(
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
}
