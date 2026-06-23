use async_trait::async_trait;
use chrono::NaiveDate;
use maohuoban_profile_domain::profile::{ProfileResult, UserGender, UserProfile};
use uuid::Uuid;

/// `DefaultProfileInput` 默认资料创建输入
/// 核心职责：
/// - 承接认证域创建用户后的最小资料初始化参数
/// - 避免 Profile 应用层依赖认证仓储行结构
#[derive(Debug, Clone)]
pub struct DefaultProfileInput {
    pub user_id: Uuid,
}

/// `UpdateProfileInput` 当前用户资料更新输入
/// 核心职责：
/// - 承载个人资料可编辑字段的局部更新
/// - 保持 HTTP DTO 与仓储行结构解耦
#[derive(Debug, Clone)]
pub struct UpdateProfileInput {
    pub user_id: Uuid,
    pub display_name: Option<String>,
    pub bio: Option<String>,
    pub gender: Option<UserGender>,
    pub is_gender_visible: Option<bool>,
    pub birthday: Option<NaiveDate>,
}

/// `ProfileMediaKind` 用户资料媒体类型
/// 核心职责：
/// - 区分头像和主页背景两类资料媒体
/// - 为仓储选择资料字段和媒资用途提供稳定输入
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProfileMediaKind {
    Avatar,
    Cover,
}

impl ProfileMediaKind {
    #[must_use]
    pub const fn usage_kind(self) -> &'static str {
        match self {
            Self::Avatar => "user.avatar",
            Self::Cover => "user.cover.image",
        }
    }

    #[must_use]
    pub const fn size_limit_bytes(self) -> usize {
        match self {
            Self::Avatar => 5 * 1024 * 1024,
            Self::Cover => 10 * 1024 * 1024,
        }
    }

    #[must_use]
    pub const fn path_segment(self) -> &'static str {
        match self {
            Self::Avatar => "avatar",
            Self::Cover => "cover",
        }
    }
}

/// `UploadProfileMediaInput` 用户资料媒体上传输入
/// 核心职责：
/// - 承接 HTTP multipart 解包后的图片内容
/// - 保持应用层上传命令与具体 HTTP 框架解耦
#[derive(Debug, Clone)]
pub struct UploadProfileMediaInput {
    pub user_id: Uuid,
    pub kind: ProfileMediaKind,
    pub file_name: String,
    pub mime_type: String,
    pub content: Vec<u8>,
    pub source_client: Option<String>,
}

/// `ProfileRepository` 用户资料仓储端口
/// 核心职责：
/// - 读取当前用户资料
/// - 为新账号幂等创建默认资料
/// - 持久化当前用户资料的可编辑字段
#[async_trait]
pub trait ProfileRepository: Send + Sync {
    async fn find_by_user_id(&self, user_id: Uuid) -> ProfileResult<Option<UserProfile>>;

    async fn create_default_profile(
        &self,
        input: DefaultProfileInput,
    ) -> ProfileResult<UserProfile>;

    async fn update_profile(&self, input: UpdateProfileInput) -> ProfileResult<UserProfile>;

    async fn upload_profile_media(
        &self,
        input: UploadProfileMediaInput,
    ) -> ProfileResult<UserProfile>;
}
