#![allow(clippy::needless_pass_by_value)]

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
