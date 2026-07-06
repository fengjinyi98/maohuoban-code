use chrono::{DateTime, Utc};
use maohuoban_home_http::home::{HomeRealtimeEvent, HomeRealtimeEventKind, HomeRealtimeHub};
use sqlx::PgPool;
use uuid::Uuid;

use super::{AgentFollowupSchedulerError, AgentFollowupSchedulerRunResult};

/// `run_once` 执行一次 Agent 主动追踪到期投影
/// 核心职责：
/// - 调用数据库调度函数领取到期追踪计划
/// - 将 due plan 投影为首页站内轻提醒
///
/// # Errors
/// 当数据库调度函数执行失败时返回错误。
pub async fn run_once(
    pool: &PgPool,
    now_at: DateTime<Utc>,
    realtime_hub: &HomeRealtimeHub,
) -> Result<AgentFollowupSchedulerRunResult, AgentFollowupSchedulerError> {
    let projection_started_at = Utc::now();
    let projected_hints: i64 =
        sqlx::query_scalar(r"SELECT project_due_agent_proactive_followups($1::timestamptz)")
            .bind(now_at)
            .fetch_one(pool)
            .await?;
    let proactive_messages = write_due_followup_agent_messages(pool, now_at).await?;
    if projected_hints > 0 {
        publish_projected_attention_hints(pool, projection_started_at, realtime_hub).await?;
    }

    Ok(AgentFollowupSchedulerRunResult {
        projected_hints,
        proactive_messages,
    })
}

struct ProjectedAttentionHintEvent {
    actor_user_id: Uuid,
    pet_id: Uuid,
    hint_id: Uuid,
    source_ref_type: String,
    source_ref_id: Uuid,
    occurred_at: DateTime<Utc>,
}

async fn publish_projected_attention_hints(
    pool: &PgPool,
    projection_started_at: DateTime<Utc>,
    realtime_hub: &HomeRealtimeHub,
) -> Result<(), AgentFollowupSchedulerError> {
    let projected_hints = sqlx::query_as::<_, (Uuid, Uuid, Uuid, String, Uuid, DateTime<Utc>)>(
        r"
        SELECT p.owner_user_id,
               h.pet_id,
               h.id,
               h.source_ref_type,
               h.source_ref_id,
               h.updated_at
        FROM attention_hints h
        JOIN pet_profiles p ON p.id = h.pet_id
        JOIN agent_proactive_followups f
          ON h.source_ref_type = 'agent_proactive_followup'
         AND h.source_ref_id = f.id
        WHERE h.kind = 'abnormal_followup_due'
          AND h.status = 'active'
          AND f.status = 'due'
          AND f.updated_at >= $1
        ORDER BY h.updated_at ASC
        ",
    )
    .bind(projection_started_at)
    .fetch_all(pool)
    .await?;

    for (actor_user_id, pet_id, hint_id, source_ref_type, source_ref_id, occurred_at) in
        projected_hints
    {
        let event = ProjectedAttentionHintEvent {
            actor_user_id,
            pet_id,
            hint_id,
            source_ref_type,
            source_ref_id,
            occurred_at,
        };
        realtime_hub.publish(HomeRealtimeEvent {
            actor_user_id: event.actor_user_id,
            pet_id: event.pet_id,
            hint_id: Some(event.hint_id),
            kind: HomeRealtimeEventKind::AttentionHintProjected,
            source_ref_type: event.source_ref_type,
            source_ref_id: event.source_ref_id,
            occurred_at: event.occurred_at,
        });
    }

    Ok(())
}

struct DueFollowupMessageTarget {
    followup_id: Uuid,
    pet_id: Uuid,
    episode_id: Uuid,
    actor_user_id: Uuid,
    pet_name: String,
    pet_species: String,
    profile_number: String,
    message_body: String,
}

async fn write_due_followup_agent_messages(
    pool: &PgPool,
    now_at: DateTime<Utc>,
) -> Result<i64, AgentFollowupSchedulerError> {
    let targets = load_due_followup_message_targets(pool, now_at).await?;
    let mut written = 0;
    for target in targets {
        if write_due_followup_agent_message(pool, &target, now_at).await? {
            written += 1;
        }
    }
    Ok(written)
}

async fn load_due_followup_message_targets(
    pool: &PgPool,
    now_at: DateTime<Utc>,
) -> Result<Vec<DueFollowupMessageTarget>, AgentFollowupSchedulerError> {
    let rows = sqlx::query_as::<_, (Uuid, Uuid, Uuid, Uuid, String, String, String, String)>(
        r"
        SELECT f.id,
               f.pet_id,
               f.episode_id,
               p.owner_user_id,
               p.name,
               p.species,
               p.profile_number,
               f.message_body
        FROM agent_proactive_followups f
        JOIN pet_profiles p ON p.id = f.pet_id
        JOIN attention_hints h
          ON h.source_ref_type = 'agent_proactive_followup'
         AND h.source_ref_id = f.id
         AND h.kind = 'abnormal_followup_due'
         AND h.status = 'active'
        WHERE f.status = 'due'
          AND f.due_at <= $1
        ORDER BY f.due_at ASC
        ",
    )
    .bind(now_at)
    .fetch_all(pool)
    .await?;

    Ok(rows
        .into_iter()
        .map(
            |(
                followup_id,
                pet_id,
                episode_id,
                actor_user_id,
                pet_name,
                pet_species,
                profile_number,
                message_body,
            )| DueFollowupMessageTarget {
                followup_id,
                pet_id,
                episode_id,
                actor_user_id,
                pet_name,
                pet_species,
                profile_number,
                message_body,
            },
        )
        .collect())
}

async fn write_due_followup_agent_message(
    pool: &PgPool,
    target: &DueFollowupMessageTarget,
    now_at: DateTime<Utc>,
) -> Result<bool, AgentFollowupSchedulerError> {
    let mut tx = pool.begin().await?;
    let session_id = ensure_abnormal_followup_session(&mut tx, target, now_at).await?;
    let exists: bool = sqlx::query_scalar(
        r"
        SELECT EXISTS (
            SELECT 1
            FROM ai_messages
            WHERE session_id = $1
              AND role = 'assistant'
              AND content = $2
        )
        ",
    )
    .bind(session_id)
    .bind(&target.message_body)
    .fetch_one(&mut *tx)
    .await?;
    if exists {
        tx.commit().await?;
        return Ok(false);
    }
    let message_id = Uuid::new_v4();
    sqlx::query(
        r"
        INSERT INTO ai_messages (
            id, session_id, role, content, content_blocks, status, citations,
            created_at
        )
        VALUES ($1, $2, 'assistant', $3, '[]'::jsonb, 'completed', '[]'::jsonb, $4)
        ",
    )
    .bind(message_id)
    .bind(session_id)
    .bind(&target.message_body)
    .bind(now_at)
    .execute(&mut *tx)
    .await?;
    sqlx::query(
        r"
        UPDATE ai_chat_sessions
        SET updated_at = $3,
            last_message_at = $3
        WHERE id = $1
          AND actor_user_id = $2
        ",
    )
    .bind(session_id)
    .bind(target.actor_user_id)
    .bind(now_at)
    .execute(&mut *tx)
    .await?;
    tx.commit().await?;
    Ok(true)
}

async fn ensure_abnormal_followup_session(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    target: &DueFollowupMessageTarget,
    now_at: DateTime<Utc>,
) -> Result<Uuid, AgentFollowupSchedulerError> {
    let existing_id: Option<Uuid> = sqlx::query_scalar(
        r"
        SELECT id
        FROM ai_chat_sessions
        WHERE actor_user_id = $1
          AND abnormal_episode_id = $2
          AND status = 'active'
        ORDER BY updated_at DESC
        LIMIT 1
        ",
    )
    .bind(target.actor_user_id)
    .bind(target.episode_id)
    .fetch_optional(&mut **tx)
    .await?;
    let snapshot = serde_json::json!({
        "pet_id": target.pet_id,
        "pet_name": target.pet_name,
        "pet_avatar_url": null,
        "pet_species": target.pet_species,
        "profile_number": target.profile_number
    });
    if let Some(session_id) = existing_id {
        sqlx::query(
            r"
            UPDATE ai_chat_sessions
            SET primary_pet_id = $2,
                surface = 'home_private',
                chat_context_kind = 'abnormal_episode_followup',
                abnormal_episode_id = $3,
                agent_followup_id = $4,
                pet_display_snapshot = $5::jsonb,
                context_status = 'active',
                updated_at = $6
            WHERE id = $1
            ",
        )
        .bind(session_id)
        .bind(target.pet_id)
        .bind(target.episode_id)
        .bind(target.followup_id)
        .bind(snapshot)
        .bind(now_at)
        .execute(&mut **tx)
        .await?;
        return Ok(session_id);
    }

    let session_id = Uuid::new_v4();
    sqlx::query(
        r"
        INSERT INTO ai_chat_sessions (
            id, actor_user_id, primary_pet_id, surface, chat_context_kind,
            abnormal_episode_id, agent_followup_id, title, is_pinned,
            pet_display_snapshot, status, session_visibility, context_status,
            activated_at, created_at, updated_at
        )
        VALUES (
            $1, $2, $3, 'home_private', 'abnormal_episode_followup',
            $4, $5, $6, false,
            $7::jsonb, 'active', 'background', 'active',
            NULL, $8, $8
        )
        ",
    )
    .bind(session_id)
    .bind(target.actor_user_id)
    .bind(target.pet_id)
    .bind(target.episode_id)
    .bind(target.followup_id)
    .bind(format!("{}的异常追踪", target.pet_name))
    .bind(snapshot)
    .bind(now_at)
    .execute(&mut **tx)
    .await?;
    Ok(session_id)
}
