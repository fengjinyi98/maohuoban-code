#![allow(clippy::doc_markdown, clippy::missing_errors_doc)]

pub mod media_upload_policy;

use std::{env, fs, io, path::PathBuf};

use object_store::{
    Attribute, Attributes, Error as ObjectStoreError, ObjectStore, ObjectStoreExt, PutOptions,
    aws::AmazonS3Builder, local::LocalFileSystem, path::Path,
};
use thiserror::Error;

const DEFAULT_BUCKET: &str = "maohuoban-pet-media";
const DEFAULT_CACHE_CONTROL: &str = "public, max-age=31536000, immutable";

/// MediaStorageConfig 媒体对象存储配置
/// 核心职责：
/// - 表达本地对象根与 RustFS/S3 两类后端
/// - 提供上传和 GC 共用的默认 bucket
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MediaStorageConfig {
    Local {
        root: PathBuf,
        default_bucket: String,
        cache_control: Option<String>,
    },
    S3 {
        endpoint: String,
        access_key_id: String,
        secret_access_key: String,
        region: String,
        default_bucket: String,
        allow_http: bool,
        cache_control: Option<String>,
    },
}

impl MediaStorageConfig {
    #[must_use]
    pub fn local(root: PathBuf, default_bucket: impl Into<String>) -> Self {
        Self::Local {
            root,
            default_bucket: default_bucket.into(),
            cache_control: Some(DEFAULT_CACHE_CONTROL.to_owned()),
        }
    }

    #[must_use]
    pub fn s3(
        endpoint: impl Into<String>,
        access_key_id: impl Into<String>,
        secret_access_key: impl Into<String>,
        region: impl Into<String>,
        default_bucket: impl Into<String>,
        allow_http: bool,
    ) -> Self {
        Self::S3 {
            endpoint: endpoint.into(),
            access_key_id: access_key_id.into(),
            secret_access_key: secret_access_key.into(),
            region: region.into(),
            default_bucket: default_bucket.into(),
            allow_http,
            cache_control: Some(DEFAULT_CACHE_CONTROL.to_owned()),
        }
    }

    #[must_use]
    pub fn with_cache_control(mut self, cache_control: Option<String>) -> Self {
        match &mut self {
            Self::Local {
                cache_control: current,
                ..
            }
            | Self::S3 {
                cache_control: current,
                ..
            } => {
                *current = cache_control;
            }
        }
        self
    }

    /// from_env 读取媒体对象存储环境配置
    /// 核心职责：
    /// - 默认使用本地对象根支持测试和开发
    /// - 在显式选择 s3 时连接 RustFS/S3 endpoint
    pub fn from_env() -> MediaStorageResult<Self> {
        let backend =
            env::var("MAOHUOBAN_MEDIA_STORAGE_BACKEND").unwrap_or_else(|_| "local".to_owned());
        let default_bucket =
            env::var("MAOHUOBAN_MEDIA_S3_BUCKET").unwrap_or_else(|_| DEFAULT_BUCKET.to_owned());
        let cache_control = cache_control_from_env();
        if backend.eq_ignore_ascii_case("s3") {
            return Ok(Self::s3(
                required_env("MAOHUOBAN_MEDIA_S3_ENDPOINT")?,
                required_env("MAOHUOBAN_MEDIA_S3_ACCESS_KEY_ID")?,
                required_env("MAOHUOBAN_MEDIA_S3_SECRET_ACCESS_KEY")?,
                env::var("MAOHUOBAN_MEDIA_S3_REGION").unwrap_or_else(|_| "us-east-1".to_owned()),
                default_bucket,
                env::var("MAOHUOBAN_MEDIA_S3_ALLOW_HTTP")
                    .is_ok_and(|value| value == "true" || value == "1"),
            )
            .with_cache_control(cache_control));
        }

        let root = env::var("MAOHUOBAN_MEDIA_STORAGE_ROOT").map_or_else(
            |_| env::temp_dir().join("maohuoban-code-rustfs-media"),
            PathBuf::from,
        );
        Ok(Self::local(root, default_bucket).with_cache_control(cache_control))
    }

    #[must_use]
    pub fn default_bucket(&self) -> &str {
        match self {
            Self::Local { default_bucket, .. } | Self::S3 { default_bucket, .. } => default_bucket,
        }
    }

    #[must_use]
    pub fn cache_control(&self) -> Option<&str> {
        match self {
            Self::Local { cache_control, .. } | Self::S3 { cache_control, .. } => {
                cache_control.as_deref()
            }
        }
    }

    #[must_use]
    pub const fn is_s3(&self) -> bool {
        matches!(self, Self::S3 { .. })
    }
}

/// MediaObjectStore 媒体对象存储客户端
/// 核心职责：
/// - 为上传、派生物和 GC 提供统一 put/get/delete 行为
/// - 隐藏本地文件与 RustFS/S3 的路径差异
#[derive(Debug, Clone)]
pub struct MediaObjectStore {
    config: MediaStorageConfig,
}

impl MediaObjectStore {
    #[must_use]
    pub const fn new(config: MediaStorageConfig) -> Self {
        Self { config }
    }

    pub fn from_env() -> MediaStorageResult<Self> {
        Ok(Self::new(MediaStorageConfig::from_env()?))
    }

    #[must_use]
    pub fn default_bucket(&self) -> &str {
        self.config.default_bucket()
    }

    pub async fn put(
        &self,
        bucket: &str,
        object_key: &str,
        content: &[u8],
    ) -> MediaStorageResult<()> {
        let (store, location) = self.store_for(bucket, object_key)?;
        if let Some(cache_control) = self.config.cache_control().filter(|_| self.config.is_s3()) {
            let mut attributes = Attributes::new();
            attributes.insert(Attribute::CacheControl, cache_control.to_owned().into());
            let options = PutOptions {
                attributes,
                ..Default::default()
            };
            store
                .put_opts(&location, content.to_vec().into(), options)
                .await
                .map_err(MediaStorageError::from)?;
        } else {
            store
                .put(&location, content.to_vec().into())
                .await
                .map_err(MediaStorageError::from)?;
        }
        Ok(())
    }

    pub async fn get(&self, bucket: &str, object_key: &str) -> MediaStorageResult<Vec<u8>> {
        let (store, location) = self.store_for(bucket, object_key)?;
        let bytes = store
            .get(&location)
            .await
            .map_err(MediaStorageError::from)?
            .bytes()
            .await
            .map_err(MediaStorageError::from)?;
        Ok(bytes.to_vec())
    }

    pub async fn delete(&self, bucket: &str, object_key: &str) -> MediaStorageResult<()> {
        let (store, location) = self.store_for(bucket, object_key)?;
        match store.delete(&location).await {
            Ok(()) | Err(ObjectStoreError::NotFound { .. }) => Ok(()),
            Err(error) => Err(MediaStorageError::from(error)),
        }
    }

    fn store_for(
        &self,
        bucket: &str,
        object_key: &str,
    ) -> MediaStorageResult<(Box<dyn ObjectStore>, Path)> {
        match &self.config {
            MediaStorageConfig::Local { root, .. } => {
                fs::create_dir_all(root)?;
                let store = LocalFileSystem::new_with_prefix(root)?;
                Ok((
                    Box::new(store),
                    Path::from(format!("{bucket}/{object_key}")),
                ))
            }
            MediaStorageConfig::S3 {
                endpoint,
                access_key_id,
                secret_access_key,
                region,
                allow_http,
                ..
            } => {
                let store = AmazonS3Builder::new()
                    .with_bucket_name(bucket)
                    .with_region(region)
                    .with_endpoint(endpoint)
                    .with_access_key_id(access_key_id)
                    .with_secret_access_key(secret_access_key)
                    .with_allow_http(*allow_http)
                    .with_virtual_hosted_style_request(false)
                    .build()?;
                Ok((Box::new(store), Path::from(object_key)))
            }
        }
    }
}

/// MediaStorageError 媒体对象存储错误
/// 核心职责：
/// - 统一封装配置缺失和对象存储 SDK 错误
/// - 向上层返回可记录的基础设施错误文本
#[derive(Debug, Error)]
pub enum MediaStorageError {
    #[error("missing media storage env {0}")]
    MissingEnv(&'static str),
    #[error("object storage error: {0}")]
    ObjectStore(#[from] ObjectStoreError),
    #[error("local object storage error: {0}")]
    Io(#[from] io::Error),
}

pub type MediaStorageResult<T> = Result<T, MediaStorageError>;

fn required_env(key: &'static str) -> MediaStorageResult<String> {
    env::var(key).map_err(|_| MediaStorageError::MissingEnv(key))
}

fn cache_control_from_env() -> Option<String> {
    env::var("MAOHUOBAN_MEDIA_CACHE_CONTROL").map_or_else(
        |_| Some(DEFAULT_CACHE_CONTROL.to_owned()),
        |value| {
            let trimmed = value.trim();
            if trimmed.is_empty() {
                None
            } else {
                Some(trimmed.to_owned())
            }
        },
    )
}
