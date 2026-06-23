use async_trait::async_trait;
use chrono::{DateTime, Datelike, Duration, Utc};
use maohuoban_profile_application::profile::{
    DefaultProfileInput, ProfileRepository as ProfileRepositoryPort, UpdateProfileInput,
};
use maohuoban_profile_domain::profile::{
    ProfileError, ProfileFieldEditPolicy, ProfileResult, UserProfile,
};
use sqlx::PgPool;
use uuid::Uuid;

mod rows;

use rows::UserProfileRow;

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
            Some(profile) => Ok(Some(self.attach_edit_policies(profile).await?)),
            None => Ok(None),
        }
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
