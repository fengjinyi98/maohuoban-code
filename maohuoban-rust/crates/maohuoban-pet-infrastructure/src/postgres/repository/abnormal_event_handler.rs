// AbnormalEventHandler PostgreSQL 异常事件处理
// 核心职责：
// - 当异常症状事件提交时，原子创建 abnormal_episode + attention_hint
// - 使用事务保证 episode、hint 一致性写入
// - 避免跨 crate 依赖（不引用 home-domain）

use chrono::{DateTime, Duration, Utc};
use maohuoban_pet_application::pet::{
    AbnormalSymptomEventInput, NewPetEvent, SaveAgentFollowupPlanInput, SavedAgentFollowupPlan,
};
use maohuoban_pet_domain::pet::{PetError, PetEvent, PetResult};
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
        input: AbnormalSymptomEventInput,
    ) -> maohuoban_pet_domain::pet::PetResult<Uuid> {
        let AbnormalSymptomEventInput {
            pet_id,
            actor_user_id,
            event_id,
            symptom_kinds_json: symptom_kinds_serde,
            primary_symptom: primary_symptom_serde,
            severity: severity_serde,
            started_at,
        } = input;
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
        let route_payload: serde_json::Value = serde_json::json!({
            "episode_id": episode_id,
            "event_id": event_id
        });

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

        Self::bind_event_attachment_assets_in_transaction(
            &mut tx,
            input.pet_id,
            input.actor_user_id,
            &payload,
        )
        .await?;

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
        let route_payload = serde_json::json!({
            "episode_id": episode_id,
            "event_id": event_id
        });
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

        Self::insert_initial_agent_followup_plan(
            &mut tx,
            input.pet_id,
            episode_id,
            event_id,
            input.occurred_at,
            &primary_symptom_str,
            &severity_str,
        )
        .await?;

        tx.commit().await.map_err(to_infrastructure_error)?;

        row.try_into()
    }

    /// insert_initial_agent_followup_plan 写入异常创建后的主动追踪初始计划
    /// 核心职责：
    /// - 生成默认 scheduled followup，保证异常创建后进入主动追踪队列
    /// - 回写 episode 的 next_followup_due_at 和 last_followup_plan_id
    /// - 后续 Agent planning skill 可基于事实替换为更精细计划
    async fn insert_initial_agent_followup_plan(
        tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
        pet_id: Uuid,
        episode_id: Uuid,
        event_id: Uuid,
        occurred_at: DateTime<Utc>,
        primary_symptom: &str,
        severity: &str,
    ) -> PetResult<Uuid> {
        let followup_id = Uuid::new_v4();
        let due_at = occurred_at + initial_followup_delay(severity);
        let message_body = initial_followup_message(primary_symptom);
        let recommended_actions = serde_json::json!(["update_observation", "chat_with_agent"]);

        sqlx::query(
            r#"
            INSERT INTO agent_proactive_followups (
                id, pet_id, episode_id, trigger_event_id, status,
                due_at, message_title, message_body, rationale, recommended_actions,
                created_at, updated_at
            )
            VALUES (
                $1, $2, $3, $4, 'scheduled',
                $5, '毛球想确认一下', $6,
                '异常创建后生成首轮主动追踪计划，等待 Agent planning skill 细化。',
                $7::jsonb,
                now(), now()
            )
            "#,
        )
        .bind(followup_id)
        .bind(pet_id)
        .bind(episode_id)
        .bind(event_id)
        .bind(due_at)
        .bind(&message_body)
        .bind(&recommended_actions)
        .execute(&mut **tx)
        .await
        .map_err(to_infrastructure_error)?;

        sqlx::query(
            r#"
            UPDATE abnormal_episodes
            SET next_followup_due_at = $1,
                last_followup_plan_id = $2,
                updated_at = now()
            WHERE id = $3
            "#,
        )
        .bind(due_at)
        .bind(followup_id)
        .bind(episode_id)
        .execute(&mut **tx)
        .await
        .map_err(to_infrastructure_error)?;

        Ok(followup_id)
    }

    /// insert_followup_replan 写入追加观察后的下一轮主动追踪计划
    /// 核心职责：
    /// - 在用户更新异常后生成下一轮默认追踪计划
    /// - 回写 episode 的 next_followup_due_at 和 last_followup_plan_id
    /// - 为后续 Agent planning skill 动态替换计划保留稳定落点
    async fn insert_followup_replan(
        tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
        pet_id: Uuid,
        episode_id: Uuid,
        trigger_event_id: Uuid,
        observed_at: DateTime<Utc>,
    ) -> PetResult<Uuid> {
        let followup_id = Uuid::new_v4();
        let due_at = observed_at + followup_replan_delay();
        let recommended_actions = serde_json::json!(["update_observation", "chat_with_agent"]);

        sqlx::query(
            r#"
            INSERT INTO agent_proactive_followups (
                id, pet_id, episode_id, trigger_event_id, status,
                due_at, message_title, message_body, rationale, recommended_actions,
                created_at, updated_at
            )
            VALUES (
                $1, $2, $3, $4, 'scheduled',
                $5, '毛球稍后再确认',
                '毛球会继续观察这次异常变化，稍后再提醒你更新便便、精神和食欲状态。',
                '用户追加观察后生成下一轮主动追踪计划，等待 Agent planning skill 动态细化。',
                $6::jsonb,
                now(), now()
            )
            "#,
        )
        .bind(followup_id)
        .bind(pet_id)
        .bind(episode_id)
        .bind(trigger_event_id)
        .bind(due_at)
        .bind(&recommended_actions)
        .execute(&mut **tx)
        .await
        .map_err(to_infrastructure_error)?;

        sqlx::query(
            r#"
            UPDATE abnormal_episodes
            SET next_followup_due_at = $1,
                last_followup_plan_id = $2,
                updated_at = now()
            WHERE id = $3
            "#,
        )
        .bind(due_at)
        .bind(followup_id)
        .bind(episode_id)
        .execute(&mut **tx)
        .await
        .map_err(to_infrastructure_error)?;

        Ok(followup_id)
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

        // 3. 终止 Agent 主动追踪计划和已到期轻提醒
        sqlx::query(
            r#"
            UPDATE agent_proactive_followups
            SET status = 'resolved',
                resolved_at = now(),
                updated_at = now()
            WHERE episode_id = $1::uuid
              AND status IN ('planning', 'scheduled', 'due')
            "#,
        )
        .bind(episode_id)
        .execute(&mut *tx)
        .await
        .map_err(to_infrastructure_error)?;

        sqlx::query(
            r#"
            UPDATE attention_hints
            SET status = 'resolved',
                resolved_at = now(),
                updated_at = now()
            WHERE source_ref_type = 'agent_proactive_followup'
              AND source_ref_id IN (
                  SELECT id FROM agent_proactive_followups
                  WHERE episode_id = $1::uuid
              )
              AND kind = 'abnormal_followup_due'
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

        let mut tx = self.pool.begin().await.map_err(to_infrastructure_error)?;

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
        .execute(&mut *tx)
        .await
        .map_err(to_infrastructure_error)?;

        sqlx::query(
            r#"
            UPDATE agent_proactive_followups
            SET status = 'answered',
                resolved_at = now(),
                updated_at = now()
            WHERE episode_id = $1::uuid
              AND status IN ('scheduled', 'due')
            "#,
        )
        .bind(episode_id)
        .execute(&mut *tx)
        .await
        .map_err(to_infrastructure_error)?;

        sqlx::query(
            r#"
            UPDATE attention_hints
            SET status = 'resolved',
                resolved_at = now(),
                updated_at = now()
            WHERE source_ref_type = 'agent_proactive_followup'
              AND source_ref_id IN (
                  SELECT id FROM agent_proactive_followups
                  WHERE episode_id = $1::uuid
              )
              AND kind = 'abnormal_followup_due'
              AND status = 'active'
            "#,
        )
        .bind(episode_id)
        .execute(&mut *tx)
        .await
        .map_err(to_infrastructure_error)?;

        Self::insert_followup_replan(&mut tx, pet_id, episode_id, event_id, observed_at).await?;

        tx.commit().await.map_err(to_infrastructure_error)?;

        Ok(())
    }

    /// save_agent_followup_plan_command 保存 Agent 规划后的主动追踪计划
    /// 核心职责：
    /// - 只更新已绑定当前宠物和 episode 的计划
    /// - 同步回写 abnormal episode 下一次追踪投影
    pub(super) async fn save_agent_followup_plan_command(
        &self,
        input: SaveAgentFollowupPlanInput,
    ) -> PetResult<SavedAgentFollowupPlan> {
        let recommended_actions = serde_json::to_value(&input.recommended_actions)
            .map_err(|error| PetError::InvalidInput(error.to_string()))?;
        let mut tx = self.pool.begin().await.map_err(to_infrastructure_error)?;

        let updated: Option<(Uuid, DateTime<Utc>)> = sqlx::query_as(
            r#"
            UPDATE agent_proactive_followups
            SET status = 'scheduled',
                due_at = $4,
                message_title = $5,
                message_body = $6,
                rationale = $7,
                recommended_actions = $8::jsonb,
                updated_at = now()
            WHERE id = $1
              AND pet_id = $2
              AND episode_id = $3
              AND status IN ('planning', 'scheduled', 'due')
            RETURNING id, due_at
            "#,
        )
        .bind(input.followup_id)
        .bind(input.pet_id)
        .bind(input.episode_id)
        .bind(input.due_at)
        .bind(&input.message_title)
        .bind(&input.message_body)
        .bind(&input.rationale)
        .bind(&recommended_actions)
        .fetch_optional(&mut *tx)
        .await
        .map_err(to_infrastructure_error)?;

        let Some((followup_id, due_at)) = updated else {
            return Err(PetError::InvalidInput("主动追踪计划不可用".to_owned()));
        };

        sqlx::query(
            r#"
            UPDATE abnormal_episodes
            SET next_followup_due_at = $1,
                last_followup_plan_id = $2,
                updated_at = now()
            WHERE id = $3
              AND pet_id = $4
            "#,
        )
        .bind(due_at)
        .bind(followup_id)
        .bind(input.episode_id)
        .bind(input.pet_id)
        .execute(&mut *tx)
        .await
        .map_err(to_infrastructure_error)?;

        tx.commit().await.map_err(to_infrastructure_error)?;
        Ok(SavedAgentFollowupPlan {
            followup_id,
            due_at,
        })
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
            WHERE pet_id = $1::uuid
              AND status = 'active'
              AND (display_from IS NULL OR display_from <= now())
              AND (display_until IS NULL OR display_until > now())
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

fn initial_followup_delay(severity: &str) -> Duration {
    match severity {
        "severe" => Duration::hours(2),
        "obvious" => Duration::hours(6),
        _ => Duration::hours(10),
    }
}

fn followup_replan_delay() -> Duration {
    Duration::hours(12)
}

fn initial_followup_message(primary_symptom: &str) -> String {
    let symptom_text = match primary_symptom {
        "stool" => "便便",
        "appetite" => "食欲",
        "energy" => "精神",
        "vomit" => "呕吐",
        _ => "异常",
    };
    format!("{symptom_text}异常已经过了一段时间，情况有变化吗？可以更新便便、精神和食欲状态。")
}
