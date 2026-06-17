#![allow(clippy::doc_markdown, clippy::needless_raw_string_hashes)]

use std::{fs, path::Path};

use chrono::{Duration, Utc};
use maohuoban_media_gc_worker::{MediaGcWorkerConfig, run_once};
use maohuoban_media_storage::{MediaObjectStore, MediaStorageConfig};
use maohuoban_rust::{BackendConfig, build_backend_app};
use sqlx::PgPool;
use uuid::Uuid;

/// reset_media_tables 清理媒体 worker 契约测试数据
/// 核心职责：
/// - 清空媒体和宠物相关表
/// - 保证每个 worker 测试独立可重复
async fn reset_media_tables(pool: &PgPool) {
    sqlx::query(
        r#"
        TRUNCATE TABLE
            media_audit_events,
            media_cleanup_jobs,
            media_bindings,
            media_derivatives,
            media_assets,
            pet_profiles,
            users
        CASCADE
        "#,
    )
    .execute(pool)
    .await
    .expect("reset media tables");
}

#[tokio::test]
async fn run_once_deletes_due_media_objects_and_marks_job_succeeded() {
    let app = build_backend_app(BackendConfig::local_test())
        .await
        .expect("build backend app");
    reset_media_tables(&app.pool).await;

    let storage_root =
        std::env::temp_dir().join(format!("maohuoban-media-gc-test-{}", Uuid::new_v4()));
    let bucket = "maohuoban-pet-media";
    let object_key = "pets/pet-1/pet/avatar/avatar.txt";
    let derivative_key = "pets/pet-1/pet/avatar/derivatives/thumbnail/thumbnail.png";
    let object_path = storage_root.join(bucket).join(object_key);
    let derivative_path = storage_root.join(bucket).join(derivative_key);
    fs::create_dir_all(object_path.parent().expect("object parent")).expect("create object parent");
    fs::create_dir_all(derivative_path.parent().expect("derivative parent"))
        .expect("create derivative parent");
    fs::write(&object_path, b"old-avatar").expect("write object");
    fs::write(&derivative_path, b"old-thumbnail").expect("write derivative");

    let user_id = Uuid::new_v4();
    let pet_id = Uuid::new_v4();
    let asset_id = Uuid::new_v4();
    let job_id = Uuid::new_v4();
    seed_due_cleanup_job(
        &app.pool, user_id, pet_id, asset_id, job_id, bucket, object_key,
    )
    .await;
    seed_media_derivative(&app.pool, asset_id, bucket, derivative_key).await;

    let result = run_once(MediaGcWorkerConfig {
        pool: app.pool.clone(),
        object_store: MediaObjectStore::new(MediaStorageConfig::local(
            storage_root.clone(),
            bucket,
        )),
        batch_size: 10,
    })
    .await
    .expect("run gc worker");

    assert_eq!(result.deleted_assets, 1);
    assert!(
        !Path::new(&object_path).exists(),
        "worker should delete RustFS object file"
    );
    assert!(
        !Path::new(&derivative_path).exists(),
        "worker should delete RustFS derivative object file"
    );

    let (asset_status, job_status): (String, String) = sqlx::query_as(
        r#"
        SELECT asset.status, job.status
        FROM media_assets asset
        INNER JOIN media_cleanup_jobs job ON job.asset_id = asset.id
        WHERE asset.id = $1
        "#,
    )
    .bind(asset_id)
    .fetch_one(&app.pool)
    .await
    .expect("read cleanup result");
    assert_eq!(asset_status, "deleted");
    assert_eq!(job_status, "succeeded");
}

#[tokio::test]
#[ignore = "requires PostgreSQL and a running RustFS/S3 endpoint configured with MAOHUOBAN_MEDIA_STORAGE_BACKEND=s3"]
async fn run_once_deletes_due_rustfs_s3_object_when_env_configured() {
    let app = build_backend_app(BackendConfig::local_test())
        .await
        .expect("build backend app");
    reset_media_tables(&app.pool).await;

    let object_store = MediaObjectStore::from_env().expect("read rustfs s3 config");
    let bucket = object_store.default_bucket().to_owned();
    let object_key = format!("gc-contract/{}/avatar.txt", Uuid::new_v4());
    object_store
        .put(&bucket, &object_key, b"rustfs-old-avatar")
        .await
        .expect("write rustfs object");

    let user_id = Uuid::new_v4();
    let pet_id = Uuid::new_v4();
    let asset_id = Uuid::new_v4();
    let job_id = Uuid::new_v4();
    seed_due_cleanup_job(
        &app.pool,
        user_id,
        pet_id,
        asset_id,
        job_id,
        &bucket,
        &object_key,
    )
    .await;

    let result = run_once(MediaGcWorkerConfig {
        pool: app.pool.clone(),
        object_store: object_store.clone(),
        batch_size: 10,
    })
    .await
    .expect("run rustfs gc worker");

    assert_eq!(result.deleted_assets, 1);
    assert!(
        object_store.get(&bucket, &object_key).await.is_err(),
        "worker should delete RustFS S3 object"
    );
}

/// seed_media_derivative 写入媒体派生对象记录
/// 核心职责：
/// - 准备待清理资产的派生对象
/// - 验证 GC worker 同时清理原始对象和派生对象
async fn seed_media_derivative(pool: &PgPool, asset_id: Uuid, bucket: &str, object_key: &str) {
    sqlx::query(
        r#"
        INSERT INTO media_derivatives (
            id,
            parent_asset_id,
            derivative_kind,
            bucket,
            object_key,
            mime_type,
            byte_size,
            sha256_hex,
            metadata
        )
        VALUES ($1, $2, 'thumbnail', $3, $4, 'image/png', 13, $5, '{}')
        "#,
    )
    .bind(Uuid::new_v4())
    .bind(asset_id)
    .bind(bucket)
    .bind(object_key)
    .bind("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
    .execute(pool)
    .await
    .expect("seed derivative");
}

/// seed_due_cleanup_job 写入到期清理任务
/// 核心职责：
/// - 准备用户、宠物、媒体资产和清理任务
/// - 让 worker 测试覆盖真实 PostgreSQL 状态转换
async fn seed_due_cleanup_job(
    pool: &PgPool,
    user_id: Uuid,
    pet_id: Uuid,
    asset_id: Uuid,
    job_id: Uuid,
    bucket: &str,
    object_key: &str,
) {
    sqlx::query(
        r#"
        INSERT INTO users (id, status, created_at, updated_at)
        VALUES ($1, 'active', now(), now())
        "#,
    )
    .bind(user_id)
    .execute(pool)
    .await
    .expect("seed user");

    sqlx::query(
        r#"
        INSERT INTO pet_profiles (
            id,
            owner_user_id,
            name,
            species,
            sex,
            profile_number
        )
        VALUES ($1, $2, '芝麻', 'dog', 'male', '0000000000000999')
        "#,
    )
    .bind(pet_id)
    .bind(user_id)
    .execute(pool)
    .await
    .expect("seed pet");

    let due_at = Utc::now() - Duration::minutes(1);
    sqlx::query(
        r#"
        INSERT INTO media_assets (
            id,
            uploaded_by_user_id,
            owner_pet_id,
            usage_kind,
            mime_type,
            byte_size,
            sha256_hex,
            bucket,
            object_key,
            status,
            delete_after
        )
        VALUES ($1, $2, $3, 'pet.avatar', 'text/plain', 10, $4, $5, $6, 'cleanup_pending', $7)
        "#,
    )
    .bind(asset_id)
    .bind(user_id)
    .bind(pet_id)
    .bind("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    .bind(bucket)
    .bind(object_key)
    .bind(due_at)
    .execute(pool)
    .await
    .expect("seed asset");

    sqlx::query(
        r#"
        INSERT INTO media_cleanup_jobs (id, asset_id, status, run_after)
        VALUES ($1, $2, 'queued', $3)
        "#,
    )
    .bind(job_id)
    .bind(asset_id)
    .bind(due_at)
    .execute(pool)
    .await
    .expect("seed cleanup job");
}
