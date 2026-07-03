#![allow(clippy::doc_markdown, clippy::needless_pass_by_value)]

use maohuoban_rust::{BackendConfig, build_backend_app};

use sqlx::PgPool;

/// `migrated_pool` 运行后端迁移并返回测试数据库连接池
/// 核心职责：
/// - 使用真实后端装配路径执行迁移
/// - 为宠物 schema 契约测试提供数据库查询入口
async fn migrated_pool() -> PgPool {
    build_backend_app(BackendConfig::local_test())
        .await
        .expect("build backend app")
        .pool
}

/// `column_type` 读取指定表字段类型
/// 核心职责：
/// - 从 `information_schema` 查询迁移后的字段类型
/// - 让测试聚焦外部 schema 契约
async fn column_type(pool: &PgPool, table: &str, column: &str) -> Option<String> {
    sqlx::query_scalar(
        r"
        SELECT data_type
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = $1
          AND column_name = $2
        ",
    )
    .bind(table)
    .bind(column)
    .fetch_optional(pool)
    .await
    .expect("read column type")
}

/// `index_exists` 判断索引是否存在
/// 核心职责：
/// - 查询 `PostgreSQL` 索引目录
/// - 锁定首页读模型所需查询路径
async fn index_exists(pool: &PgPool, index_name: &str) -> bool {
    sqlx::query_scalar::<_, bool>(
        r"
        SELECT EXISTS (
            SELECT 1
            FROM pg_indexes
            WHERE schemaname = 'public'
              AND indexname = $1
        )
        ",
    )
    .bind(index_name)
    .fetch_one(pool)
    .await
    .expect("read index existence")
}

/// `constraint_exists` 判断约束是否存在
/// 核心职责：
/// - 查询 `PostgreSQL` 约束目录
/// - 锁定跨表追溯关系和追加型事件约束
async fn constraint_exists(pool: &PgPool, constraint_name: &str) -> bool {
    sqlx::query_scalar::<_, bool>(
        r"
        SELECT EXISTS (
            SELECT 1
            FROM pg_constraint
            WHERE conname = $1
        )
        ",
    )
    .bind(constraint_name)
    .fetch_one(pool)
    .await
    .expect("read constraint existence")
}

/// `constraint_definition` 读取约束定义
/// 核心职责：
/// - 查询 `PostgreSQL` 约束表达式
/// - 验证追加型迁移保留既有合法取值
async fn constraint_definition(pool: &PgPool, constraint_name: &str) -> Option<String> {
    sqlx::query_scalar(
        r"
        SELECT pg_get_constraintdef(oid)
        FROM pg_constraint
        WHERE conname = $1
        ",
    )
    .bind(constraint_name)
    .fetch_optional(pool)
    .await
    .expect("read constraint definition")
}

/// `table_exists` 判断表是否存在
/// 核心职责：
/// - 查询 `PostgreSQL` information_schema
/// - 锁定媒体生命周期元数据表契约
async fn table_exists(pool: &PgPool, table: &str) -> bool {
    sqlx::query_scalar::<_, bool>(
        r"
        SELECT EXISTS (
            SELECT 1
            FROM information_schema.tables
            WHERE table_schema = 'public'
              AND table_name = $1
        )
        ",
    )
    .bind(table)
    .fetch_one(pool)
    .await
    .expect("read table existence")
}

#[tokio::test]
async fn pet_home_baseline_migration_uses_uuid_and_query_indexes() {
    let pool = migrated_pool().await;

    for table in [
        "merchant_profiles",
        "pet_profiles",
        "litters",
        "pet_relationships",
        "pet_events",
        "evidence_snapshots",
    ] {
        assert_eq!(
            column_type(&pool, table, "id").await.as_deref(),
            Some("uuid"),
            "{table}.id should use PostgreSQL uuid"
        );
    }

    assert_eq!(
        column_type(&pool, "pet_events", "event_payload")
            .await
            .as_deref(),
        Some("jsonb"),
        "pet_events.event_payload should store typed event details"
    );
    assert_eq!(
        column_type(&pool, "evidence_snapshots", "snapshot_payload")
            .await
            .as_deref(),
        Some("jsonb"),
        "evidence_snapshots.snapshot_payload should preserve publish-time evidence"
    );

    for index_name in [
        "idx_pet_events_pet_occurred_at",
        "idx_pet_events_litter_occurred_at",
        "idx_pet_profiles_merchant_status",
        "idx_litters_merchant_born_at",
        "idx_pet_relationships_subject_kind",
    ] {
        assert!(
            index_exists(&pool, index_name).await,
            "{index_name} should exist"
        );
    }
}

#[tokio::test]
async fn pet_home_baseline_migration_preserves_traceability_constraints() {
    let pool = migrated_pool().await;

    for constraint_name in [
        "fk_pet_profiles_owner_user",
        "fk_pet_profiles_merchant",
        "fk_litters_sire_pet",
        "fk_litters_dam_pet",
        "fk_pet_events_pet",
        "fk_pet_events_litter",
        "fk_pet_events_evidence_snapshot",
        "ck_pet_events_subject_present",
        "ck_pet_events_record_revision_positive",
        "fk_pet_relationships_subject_pet",
        "fk_pet_relationships_related_pet",
    ] {
        assert!(
            constraint_exists(&pool, constraint_name).await,
            "{constraint_name} should exist"
        );
    }
}

#[tokio::test]
async fn pet_profile_media_migration_adds_profile_identity_and_recovery_fields() {
    let pool = migrated_pool().await;

    for (column, expected_type) in [
        ("profile_number", "text"),
        ("microchip_number", "text"),
        ("arrival_date", "date"),
        ("weight_grams", "integer"),
        ("neuter_status", "text"),
        ("personality_tags", "jsonb"),
        ("note", "text"),
        ("background_asset_id", "uuid"),
        ("background_media_kind", "text"),
        ("deleted_at", "timestamp with time zone"),
        ("delete_requested_by_user_id", "uuid"),
        ("recoverable_until", "timestamp with time zone"),
        ("delete_reason", "text"),
    ] {
        assert_eq!(
            column_type(&pool, "pet_profiles", column).await.as_deref(),
            Some(expected_type),
            "pet_profiles.{column} should exist"
        );
    }

    for index_name in [
        "idx_pet_profiles_profile_number",
        "idx_pet_profiles_owner_active",
        "idx_pet_profiles_recoverable_until",
    ] {
        assert!(
            index_exists(&pool, index_name).await,
            "{index_name} should exist"
        );
    }
}

#[tokio::test]
async fn pet_profile_media_migration_adds_media_lifecycle_tables() {
    let pool = migrated_pool().await;

    for table in [
        "media_assets",
        "media_derivatives",
        "media_bindings",
        "media_cleanup_jobs",
        "media_audit_events",
    ] {
        assert!(table_exists(&pool, table).await, "{table} should exist");
        assert_eq!(
            column_type(&pool, table, "id").await.as_deref(),
            Some("uuid"),
            "{table}.id should use PostgreSQL uuid"
        );
    }

    for (table, column, expected_type) in [
        ("media_assets", "bucket", "text"),
        ("media_assets", "object_key", "text"),
        ("media_assets", "sha256_hex", "text"),
        ("media_assets", "status", "text"),
        ("media_assets", "width", "integer"),
        ("media_assets", "height", "integer"),
        ("media_assets", "delete_after", "timestamp with time zone"),
        ("media_derivatives", "parent_asset_id", "uuid"),
        ("media_derivatives", "metadata", "jsonb"),
        ("media_bindings", "pet_id", "uuid"),
        ("media_bindings", "usage_kind", "text"),
        ("media_bindings", "status", "text"),
        ("media_cleanup_jobs", "asset_id", "uuid"),
        ("media_cleanup_jobs", "status", "text"),
        ("media_audit_events", "asset_id", "uuid"),
        ("media_audit_events", "event_kind", "text"),
    ] {
        assert_eq!(
            column_type(&pool, table, column).await.as_deref(),
            Some(expected_type),
            "{table}.{column} should exist"
        );
    }

    for constraint_name in [
        "fk_media_assets_pet",
        "fk_media_assets_uploaded_by",
        "fk_media_derivatives_parent",
        "fk_media_bindings_asset",
        "fk_media_bindings_pet",
        "fk_media_cleanup_jobs_asset",
        "fk_media_audit_events_asset",
    ] {
        assert!(
            constraint_exists(&pool, constraint_name).await,
            "{constraint_name} should exist"
        );
    }
}

#[tokio::test]
async fn media_assets_usage_kind_constraint_preserves_profile_and_pet_album_values() {
    let pool = migrated_pool().await;

    let definition = constraint_definition(&pool, "ck_media_assets_usage_kind")
        .await
        .expect("media_assets usage_kind constraint should exist");

    for usage_kind in [
        "pet.avatar",
        "pet.background.image",
        "pet.background.video",
        "pet.background.live_photo",
        "user.avatar",
        "user.cover.image",
        "pet.album.photo",
    ] {
        assert!(
            definition.contains(usage_kind),
            "media_assets usage_kind constraint should allow {usage_kind}"
        );
    }
}
