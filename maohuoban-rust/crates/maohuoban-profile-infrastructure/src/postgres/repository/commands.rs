use maohuoban_profile_application::profile::{DefaultProfileInput, UpdateProfileInput};
use maohuoban_profile_domain::profile::{ProfileError, ProfileResult, UserProfile};

use super::PostgresProfileRepository;
use super::helpers::{generate_maohuoban_id, to_profile_error};
use super::rows::UserProfileRow;

impl PostgresProfileRepository {
    pub(super) async fn insert_default_profile(
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

    pub(super) async fn update_profile_row(
        &self,
        input: UpdateProfileInput,
    ) -> ProfileResult<UserProfile> {
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

        let gender = input.gender.map(|g| g.as_str().to_owned());

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
}
