#![allow(
    clippy::doc_markdown,
    clippy::missing_errors_doc,
    clippy::needless_raw_string_hashes
)]

use std::collections::HashSet;

use maohuoban_media_storage::MediaObjectStore;
use sqlx::{FromRow, PgPool};
use thiserror::Error;
use uuid::Uuid;

/// MediaGcWorkerConfig 媒体清理 worker 配置
/// 核心职责：
/// - 持有 PostgreSQL 连接池
/// - 指定媒体对象存储和批量领取数量
#[derive(Debug, Clone)]
pub struct MediaGcWorkerConfig {
    pub pool: PgPool,
    pub object_store: MediaObjectStore,
    pub batch_size: i64,
}

/// MediaGcRunResult 媒体清理运行结果
/// 核心职责：
/// - 返回本次成功删除的资产数量
/// - 为测试和运维日志提供可观测摘要
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct MediaGcRunResult {
    pub deleted_assets: usize,
}

/// run_once 执行一次媒体清理
/// 核心职责：
/// - 领取到期媒体清理任务
/// - 删除 RustFS 对象文件并回写数据库状态
pub async fn run_once(config: MediaGcWorkerConfig) -> Result<MediaGcRunResult, MediaGcWorkerError> {
    let jobs = claim_due_jobs(&config.pool, config.batch_size).await?;
    let mut deleted_assets = 0;

    for job in jobs {
        match delete_asset_objects(&config.object_store, &config.pool, &job).await {
            Ok(()) => {
                mark_job_succeeded(&config.pool, &job).await?;
                deleted_assets += 1;
            }
            Err(error) => {
                mark_job_failed(&config.pool, job.job_id, &error.to_string()).await?;
            }
        }
    }

    Ok(MediaGcRunResult { deleted_assets })
}

/// MediaGcWorkerError 媒体清理错误
/// 核心职责：
/// - 汇总数据库与对象删除失败
/// - 为 worker 入口提供统一错误输出
#[derive(Debug, Error)]
pub enum MediaGcWorkerError {
    #[error("database error: {0}")]
    Database(#[from] sqlx::Error),
    #[error("object storage error: {0}")]
    ObjectStorage(String),
}

#[derive(Debug, FromRow)]
struct ClaimedCleanupJob {
    job_id: Uuid,
    asset_id: Uuid,
    bucket: String,
    object_key: String,
    owner_pet_id: Option<Uuid>,
}

#[derive(Debug, FromRow)]
struct MediaObjectLocation {
    bucket: String,
    object_key: String,
}

async fn claim_due_jobs(
    pool: &PgPool,
    batch_size: i64,
) -> Result<Vec<ClaimedCleanupJob>, MediaGcWorkerError> {
    let jobs = sqlx::query_as::<_, ClaimedCleanupJob>(
        r#"
        UPDATE media_cleanup_jobs job
        SET status = 'running',
            attempts = attempts + 1,
            updated_at = now()
        FROM media_assets asset
        WHERE job.asset_id = asset.id
          AND job.status = 'queued'
          AND job.run_after <= now()
          AND asset.status = 'cleanup_pending'
          AND asset.delete_after <= now()
          AND job.id IN (
              SELECT queued.id
              FROM media_cleanup_jobs queued
              INNER JOIN media_assets queued_asset ON queued_asset.id = queued.asset_id
              WHERE queued.status = 'queued'
                AND queued.run_after <= now()
                AND queued_asset.status = 'cleanup_pending'
                AND queued_asset.delete_after <= now()
              ORDER BY queued.run_after ASC, queued.created_at ASC
              LIMIT $1
              FOR UPDATE SKIP LOCKED
          )
        RETURNING
            job.id AS job_id,
            asset.id AS asset_id,
            asset.bucket,
            asset.object_key,
            asset.owner_pet_id
        "#,
    )
    .bind(batch_size)
    .fetch_all(pool)
    .await?;

    Ok(jobs)
}

async fn delete_asset_objects(
    object_store: &MediaObjectStore,
    pool: &PgPool,
    job: &ClaimedCleanupJob,
) -> Result<(), MediaGcWorkerError> {
    let mut object_locations = vec![(job.bucket.clone(), job.object_key.clone())];
    object_locations.extend(load_derivative_objects(pool, job.asset_id).await?);

    let mut seen = HashSet::new();
    for (bucket, object_key) in object_locations {
        if !seen.insert(format!("{bucket}/{object_key}")) {
            continue;
        }
        object_store
            .delete(&bucket, &object_key)
            .await
            .map_err(|error| {
                MediaGcWorkerError::ObjectStorage(format!("{bucket}/{object_key}: {error}"))
            })?;
    }
    Ok(())
}

async fn load_derivative_objects(
    pool: &PgPool,
    asset_id: Uuid,
) -> Result<Vec<(String, String)>, MediaGcWorkerError> {
    let rows = sqlx::query_as::<_, MediaObjectLocation>(
        r#"
        SELECT bucket, object_key
        FROM media_derivatives
        WHERE parent_asset_id = $1
        "#,
    )
    .bind(asset_id)
    .fetch_all(pool)
    .await?;

    Ok(rows
        .into_iter()
        .map(|row| (row.bucket, row.object_key))
        .collect())
}

async fn mark_job_succeeded(
    pool: &PgPool,
    job: &ClaimedCleanupJob,
) -> Result<(), MediaGcWorkerError> {
    let mut transaction = pool.begin().await?;

    sqlx::query(
        r#"
        UPDATE media_assets
        SET status = 'deleted',
            deleted_at = now(),
            updated_at = now()
        WHERE id = $1
        "#,
    )
    .bind(job.asset_id)
    .execute(&mut *transaction)
    .await?;

    sqlx::query(
        r#"
        UPDATE media_cleanup_jobs
        SET status = 'succeeded',
            updated_at = now()
        WHERE id = $1
        "#,
    )
    .bind(job.job_id)
    .execute(&mut *transaction)
    .await?;

    sqlx::query(
        r#"
        INSERT INTO media_audit_events (
            id,
            asset_id,
            pet_id,
            event_kind,
            event_payload
        )
        VALUES ($1, $2, $3, 'deleted', $4)
        "#,
    )
    .bind(Uuid::new_v4())
    .bind(job.asset_id)
    .bind(job.owner_pet_id)
    .bind(serde_json::json!({
        "job_id": job.job_id,
        "bucket": job.bucket,
        "object_key": job.object_key
    }))
    .execute(&mut *transaction)
    .await?;

    transaction.commit().await?;
    Ok(())
}

async fn mark_job_failed(
    pool: &PgPool,
    job_id: Uuid,
    error: &str,
) -> Result<(), MediaGcWorkerError> {
    sqlx::query(
        r#"
        UPDATE media_cleanup_jobs
        SET status = 'failed',
            last_error = $2,
            updated_at = now()
        WHERE id = $1
        "#,
    )
    .bind(job_id)
    .bind(error)
    .execute(pool)
    .await?;
    Ok(())
}
