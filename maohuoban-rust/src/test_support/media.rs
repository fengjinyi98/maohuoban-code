use std::{env, fs, path::PathBuf};

use uuid::Uuid;

use super::AuthTestApp;

impl AuthTestApp {
    /// `media_cleanup_state` 读取媒体清理测试状态
    /// 核心职责：
    /// - 查询资产、绑定和清理任务状态
    /// - 为媒体替换契约测试提供断言入口
    ///
    /// # Panics
    ///
    /// 当 `asset_id` 不是合法 UUID，或数据库查询失败时触发。
    pub async fn media_cleanup_state(&self, asset_id: &str) -> MediaCleanupState {
        let asset_id = Uuid::parse_str(asset_id).expect("asset id");
        sqlx::query_as::<_, MediaCleanupState>(
            r"
            SELECT
                asset.status AS asset_status,
                binding.status AS binding_status,
                COALESCE(job.status, 'none') AS job_status
            FROM media_assets asset
            LEFT JOIN media_bindings binding ON binding.asset_id = asset.id
            LEFT JOIN media_cleanup_jobs job ON job.asset_id = asset.id
            WHERE asset.id = $1
            ",
        )
        .bind(asset_id)
        .fetch_one(&self.app.pool)
        .await
        .expect("read media cleanup state")
    }

    /// `media_object_content` 读取媒体对象测试内容
    /// 核心职责：
    /// - 从本地对象根读取已写入媒体字节
    /// - 为上传契约测试验证原始内容持久化
    ///
    /// # Panics
    ///
    /// 当对象文件不存在或无法读取时触发。
    #[must_use]
    pub fn media_object_content(&self, bucket: &str, object_key: &str) -> Vec<u8> {
        fs::read(media_storage_root().join(bucket).join(object_key))
            .expect("read media object content")
    }
}

/// `MediaCleanupState` 媒体清理测试状态
/// 核心职责：
/// - 暴露媒体资产状态
/// - 暴露绑定和清理任务状态
#[derive(Debug, sqlx::FromRow)]
pub struct MediaCleanupState {
    pub asset_status: String,
    pub binding_status: String,
    pub job_status: String,
}

fn media_storage_root() -> PathBuf {
    env::var("MAOHUOBAN_MEDIA_STORAGE_ROOT").map_or_else(
        |_| env::temp_dir().join("maohuoban-code-rustfs-media"),
        PathBuf::from,
    )
}
