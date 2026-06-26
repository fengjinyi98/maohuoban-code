// AbnormalEventHandler PostgreSQL 异常事件处理
// 核心职责：
// - 当异常症状事件提交时，原子创建 abnormal_episode + attention_hint
// - 使用事务保证 episode、hint 一致性写入
// - 避免跨 crate 依赖（不引用 home-domain）

use chrono::{DateTime, Utc};
use maohuoban_pet_application::pet::NewPetEvent;
use maohuoban_pet_domain::pet::{PetEvent, PetResult};
use uuid::Uuid;

use super::PostgresPetRepository;
use super::event_rows::PetEventRow;
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

    /// create_abnormal_symptom_event_command 事务级异常事件创建
    /// 核心职责：
    /// - 在同一个事务中写入 pet_events + abnormal_episodes + attention_hints
    /// - 自动将 episode_id 写入 event_payload
    /// - 返回包含 episode_id 的完整 PetEvent
    #[allow(clippy::too_many_lines)]
    pub(super) async fn create_abnormal_symptom_event_command(
        &self,
        input: NewPetEvent,
    ) -> PetResult<PetEvent> {
        let mut tx = self.pool.begin().await.map_err(to_infrastructure_error)?;

        let episode_id = Uuid::new_v4();
        let event_id = Uuid::new_v4();

        let symptom_kinds_str = input
            .event_payload
            .get("symptom_kinds")
            .map_or_else(|| "[]".to_owned(), std::string::ToString::to_string);
        let severity_str = input
            .event_payload
            .get("severity")
            .and_then(|v| v.as_str())
            .unwrap_or("mild")
            .to_owned();
        let primary_symptom_str = input
            .event_payload
            .get("symptom_kinds")
            .and_then(|v| v.as_array())
            .and_then(|a| a.first())
            .and_then(|v| v.as_str())
            .unwrap_or("other")
            .to_owned();
        // 注入 episode_id
        let mut payload = input.event_payload.clone();
        payload["episode_id"] = serde_json::json!(episode_id.to_string());

        // 1. pet_events
        let row = sqlx::query_as::<_, PetEventRow>(
            r#"
            INSERT INTO pet_events (
                id, pet_id, event_kind, event_subkind,
                title, summary, visibility, event_payload,
                occurred_at, actor_user_id, record_revision
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 1)
            RETURNING
                id, pet_id, litter_id, event_kind, event_subkind,
                title, summary, visibility, event_payload,
                occurred_at, actor_user_id, evidence_snapshot_id,
                record_revision, created_at, updated_at
            "#,
        )
        .bind(event_id)
        .bind(input.pet_id)
        .bind(input.event_kind.as_str())
        .bind(&input.event_subkind)
        .bind(&input.title)
        .bind(&input.summary)
        .bind(input.visibility.as_str())
        .bind(&payload)
        .bind(input.occurred_at)
        .bind(input.actor_user_id)
        .fetch_one(&mut *tx)
        .await
        .map_err(to_infrastructure_error)?;

        // 2. abnormal_episodes
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
        .bind(input.pet_id)
        .bind(&primary_symptom_str)
        .bind(&symptom_kinds_str)
        .bind(&severity_str)
        .bind(input.occurred_at)
        .bind(input.actor_user_id)
        .bind(event_id)
        .execute(&mut *tx)
        .await
        .map_err(to_infrastructure_error)?;

        // 3. attention_hints
        let route_payload = serde_json::json!({"episode_id": episode_id});
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
        .bind(input.pet_id)
        .bind(episode_id)
        .bind(&route_payload)
        .execute(&mut *tx)
        .await
        .map_err(to_infrastructure_error)?;

        tx.commit().await.map_err(to_infrastructure_error)?;

        row.try_into()
    }

    /// update_episode_for_recovery_command 标记异常 episode 恢复
    /// 核心职责：
    /// - 更新 abnormal_episodes.status = recovered, recovered_at, latest_event_id
    /// - 将关联 attention_hints 标记为 resolved
    pub(super) async fn update_episode_for_recovery_command(
        &self,
        pet_id: Uuid,
        event_id: Uuid,
        episode_id: Option<Uuid>,
        recovered_at: DateTime<Utc>,
    ) -> PetResult<()> {
        let episode_id = if let Some(eid) = episode_id {
            eid
        } else {
            // 查找该宠物最新 open episode
            sqlx::query_scalar::<_, Uuid>(
                r#"
                SELECT id FROM abnormal_episodes
                WHERE pet_id = $1::uuid AND status IN ('open', 'watching', 'recovering')
                ORDER BY created_at DESC LIMIT 1
                "#,
            )
            .bind(pet_id)
            .fetch_optional(&self.pool)
            .await
            .map_err(to_infrastructure_error)?
            .ok_or_else(|| {
                maohuoban_pet_domain::pet::PetError::InvalidInput(
                    "未找到开放的异常 episode".to_owned(),
                )
            })?
        };

        let mut tx = self.pool.begin().await.map_err(to_infrastructure_error)?;

        // 1. 更新 abnormal_episodes
        sqlx::query(
            r#"
            UPDATE abnormal_episodes
            SET status = 'recovered',
                recovered_at = $1,
                latest_event_id = $2,
                updated_at = now()
            WHERE id = $3::uuid
            "#,
        )
        .bind(recovered_at)
        .bind(event_id)
        .bind(episode_id)
        .execute(&mut *tx)
        .await
        .map_err(to_infrastructure_error)?;

        // 2. 将关联 attention_hints 标记为 resolved
        sqlx::query(
            r#"
            UPDATE attention_hints
            SET status = 'resolved',
                resolved_at = now(),
                updated_at = now()
            WHERE source_ref_id = $1::uuid
              AND source_ref_type = 'abnormal_episode'
              AND kind = 'open_abnormal_episode'
              AND status = 'active'
            "#,
        )
        .bind(episode_id)
        .execute(&mut *tx)
        .await
        .map_err(to_infrastructure_error)?;

        tx.commit().await.map_err(to_infrastructure_error)?;

        Ok(())
    }

    /// update_episode_for_followup_command 更新异常 episode 的观察时间线
    /// 核心职责：
    /// - 更新 abnormal_episodes.last_observed_at, latest_event_id
    pub(super) async fn update_episode_for_followup_command(
        &self,
        pet_id: Uuid,
        event_id: Uuid,
        episode_id: Option<Uuid>,
        observed_at: DateTime<Utc>,
    ) -> PetResult<()> {
        let episode_id = if let Some(eid) = episode_id {
            eid
        } else {
            sqlx::query_scalar::<_, Uuid>(
                r#"
                SELECT id FROM abnormal_episodes
                WHERE pet_id = $1::uuid AND status IN ('open', 'watching', 'recovering')
                ORDER BY created_at DESC LIMIT 1
                "#,
            )
            .bind(pet_id)
            .fetch_optional(&self.pool)
            .await
            .map_err(to_infrastructure_error)?
            .ok_or_else(|| {
                maohuoban_pet_domain::pet::PetError::InvalidInput(
                    "未找到开放的异常 episode".to_owned(),
                )
            })?
        };

        sqlx::query(
            r#"
            UPDATE abnormal_episodes
            SET last_observed_at = $1,
                latest_event_id = $2,
                updated_at = now()
            WHERE id = $3::uuid
            "#,
        )
        .bind(observed_at)
        .bind(event_id)
        .bind(episode_id)
        .execute(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        Ok(())
    }

    /// load_attention_hints_query 从 DB 查询 active attention_hints
    /// 核心职责：
    /// - 按 pet_id 查询 active attention_hints
    /// - 按 priority DESC, created_at DESC 排序
    pub(super) async fn load_attention_hints_query(
        &self,
        pet_id: Uuid,
    ) -> PetResult<Vec<serde_json::Value>> {
        let rows: Vec<serde_json::Value> = sqlx::query_scalar(
            r#"
            SELECT jsonb_build_object(
                'id', id,
                'pet_id', pet_id,
                'kind', kind,
                'title', title,
                'subtitle', subtitle,
                'icon', icon,
                'tone', tone,
                'priority', priority,
                'status', status,
                'source_ref_type', source_ref_type,
                'source_ref_id', source_ref_id,
                'route', jsonb_build_object(
                    'kind', route_kind,
                    'payload', route_payload
                ),
                'display_from', display_from,
                'display_until', display_until,
                'created_by', created_by,
                'created_at', created_at,
                'updated_at', updated_at,
                'resolved_at', resolved_at
            )
            FROM attention_hints
            WHERE pet_id = $1::uuid AND status = 'active'
            ORDER BY priority DESC, created_at DESC
            "#,
        )
        .bind(pet_id)
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        Ok(rows)
    }
}
