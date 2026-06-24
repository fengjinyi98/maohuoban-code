use async_trait::async_trait;
use maohuoban_profile_application::profile::{
    DefaultProfileInput, ProfileRepository as ProfileRepositoryPort, UpdateProfileInput,
    UploadProfileMediaInput,
};
use maohuoban_profile_domain::profile::{ProfileResult, UserProfile};
use sqlx::PgPool;
use uuid::Uuid;

pub(crate) mod commands;
pub(crate) mod helpers;
pub(crate) mod media;
pub(crate) mod queries;
mod rows;

const DISPLAY_NAME_EDIT_MAX_COUNT: i32 = 5;
const BIO_EDIT_MAX_COUNT: i32 = 3;
const PROFILE_FIELD_EDIT_WINDOW_DAYS: i32 = 30;

/// `PostgresProfileRepository` `PostgreSQL` 用户资料仓库
/// 核心职责：
/// - 持久化用户资料和默认资料生成结果
/// - 通过唯一索引保证用户资料和毛伙伴号唯一
#[derive(Debug, Clone)]
pub struct PostgresProfileRepository {
    pub(crate) pool: PgPool,
}

impl PostgresProfileRepository {
    #[must_use]
    pub const fn new(pool: PgPool) -> Self {
        Self { pool }
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
