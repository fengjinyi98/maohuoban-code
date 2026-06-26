// AbnormalEventHandler PostgreSQL 异常事件处理
// 核心职责：
// - 当异常症状事件提交时，原子创建 abnormal_episode + attention_hint
// - 使用事务保证 episode、hint 一致性写入
// - 避免跨 crate 依赖（不引用 home-domain）

use chrono::{DateTime, Utc};
use uuid::Uuid;

use super::PostgresPetRepository;
use super::storage::to_infrastructure_error;

impl PostgresPetRepository {
    /// handle_abnormal_symptom_event 原子创建异常 episode 和 attention hint
    /// 核心职责：
    /// - 写入 abnormal_episodes 表
    /// - 写入 attention_hints 表（kind = open_abnormal_episode）
    /// - 返回 episode_id 供调用方填充 event_payload
    pub(super) async fn handle_abnormal_symptom_event_command(
        &self,
        pet_id: Uuid,
        actor_user_id: Uuid,
        event_id: Uuid,
        symptom_kinds_serde: &str,
        primary_symptom_serde: &str,
        severity_serde: &str,
        started_at: DateTime<Utc>,
    ) -> maohuoban_pet_domain::pet::PetResult<Uuid> {
        let mut tx = self.pool.begin().await.map_err(to_infrastructure_error)?;

        let episode_id = Uuid::new_v4();

        // 1. 写入 abnormal_episodes
        sqlx::query(
            r#"
            INSERT INTO abnormal_episodes (
                id, pet_id, status, primary_symptom_kind, symptom_kinds,
                severity, started_at, created_by_user_id, created_event_id,
                created_at, updated_at
            )
            VALUES ($1, $2, 'open', $3, $4::jsonb, $5, $6, $7, $8, now(), now())
            "#,
        )
        .bind(episode_id)
        .bind(pet_id)
        .bind(primary_symptom_serde)
        .bind(symptom_kinds_serde)
        .bind(severity_serde)
        .bind(started_at)
        .bind(actor_user_id)
        .bind(event_id)
        .execute(&mut *tx)
        .await
        .map_err(to_infrastructure_error)?;

        // 2. 写入 attention_hints — route_payload 使用 jsonb 绑定
        let route_payload: serde_json::Value = serde_json::json!({"episode_id": episode_id});

        sqlx::query(
            r#"
            INSERT INTO attention_hints (
                id, pet_id, kind, title, subtitle, icon, tone, priority,
                status, source_ref_type, source_ref_id,
                route_kind, route_payload, created_by,
                created_at, updated_at
            )
            VALUES (
                $1, $2, 'open_abnormal_episode', '异常追踪', '点击查看异常详情',
                'exclamationmark.circle', 'notice', 10,
                'active', 'abnormal_episode', $3,
                'abnormal_detail', $4, 'system',
                now(), now()
            )
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(pet_id)
        .bind(episode_id)
        .bind(&route_payload)
        .execute(&mut *tx)
        .await
        .map_err(to_infrastructure_error)?;

        tx.commit().await.map_err(to_infrastructure_error)?;

        Ok(episode_id)
    }
}
