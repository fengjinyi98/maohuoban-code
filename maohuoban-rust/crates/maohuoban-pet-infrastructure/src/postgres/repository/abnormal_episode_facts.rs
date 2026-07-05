use chrono::{DateTime, Utc};
use maohuoban_pet_application::pet::{PetAbnormalEpisodeEventFact, PetAbnormalEpisodeFacts};
use maohuoban_pet_domain::pet::{PetError, PetResult};
use sqlx::FromRow;
use uuid::Uuid;

use super::PostgresPetRepository;
use super::storage::to_infrastructure_error;

#[derive(Debug, FromRow)]
struct AbnormalEpisodeFactRow {
    id: Uuid,
    pet_id: Uuid,
    status: String,
    primary_symptom_kind: Option<String>,
    severity: Option<String>,
    started_at: DateTime<Utc>,
    last_observed_at: Option<DateTime<Utc>>,
    recovered_at: Option<DateTime<Utc>>,
    created_event_id: Uuid,
    latest_event_id: Option<Uuid>,
}

#[derive(Debug, FromRow)]
struct AbnormalEpisodeEventFactRow {
    event_id: Uuid,
    event_subkind: Option<String>,
    title: String,
    summary: Option<String>,
    occurred_at: DateTime<Utc>,
    attachment_count: i64,
}

impl From<AbnormalEpisodeEventFactRow> for PetAbnormalEpisodeEventFact {
    fn from(row: AbnormalEpisodeEventFactRow) -> Self {
        Self {
            event_id: row.event_id,
            event_subkind: row.event_subkind,
            title: row.title,
            summary: row.summary,
            occurred_at: row.occurred_at,
            attachment_count: row.attachment_count,
        }
    }
}

impl PostgresPetRepository {
    /// load_abnormal_episode_facts_query 读取异常 episode 追踪事实
    /// 核心职责：
    /// - 按宠物和可选 episode_id 定位未删除 episode
    /// - 返回父异常事件和同 episode 的进展事件序列
    pub(super) async fn load_abnormal_episode_facts_query(
        &self,
        pet_id: Uuid,
        episode_id: Option<Uuid>,
    ) -> PetResult<Option<PetAbnormalEpisodeFacts>> {
        let episode = match episode_id {
            Some(id) => self.load_abnormal_episode_by_id(pet_id, id).await?,
            None => self.load_latest_abnormal_episode(pet_id).await?,
        };
        let Some(episode) = episode else {
            return Ok(None);
        };

        let initial_event = self
            .load_abnormal_episode_initial_event(episode.created_event_id)
            .await?
            .ok_or(PetError::PetEventNotFound)?;
        let timeline_events = self
            .load_abnormal_episode_timeline_events(episode.id)
            .await?;

        Ok(Some(PetAbnormalEpisodeFacts {
            episode_id: episode.id,
            pet_id: episode.pet_id,
            status: episode.status,
            primary_symptom_kind: episode.primary_symptom_kind,
            severity: episode.severity,
            started_at: episode.started_at,
            last_observed_at: episode.last_observed_at,
            recovered_at: episode.recovered_at,
            created_event_id: episode.created_event_id,
            latest_event_id: episode.latest_event_id,
            initial_event: initial_event.into(),
            timeline_events: timeline_events.into_iter().map(Into::into).collect(),
        }))
    }

    async fn load_abnormal_episode_by_id(
        &self,
        pet_id: Uuid,
        episode_id: Uuid,
    ) -> PetResult<Option<AbnormalEpisodeFactRow>> {
        sqlx::query_as::<_, AbnormalEpisodeFactRow>(
            r#"
            SELECT
                id,
                pet_id,
                status,
                primary_symptom_kind,
                severity,
                started_at,
                last_observed_at,
                recovered_at,
                created_event_id,
                latest_event_id
            FROM abnormal_episodes
            WHERE id = $1::uuid
              AND pet_id = $2::uuid
              AND status <> 'closed'
            "#,
        )
        .bind(episode_id)
        .bind(pet_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(to_infrastructure_error)
    }

    async fn load_latest_abnormal_episode(
        &self,
        pet_id: Uuid,
    ) -> PetResult<Option<AbnormalEpisodeFactRow>> {
        sqlx::query_as::<_, AbnormalEpisodeFactRow>(
            r#"
            SELECT
                id,
                pet_id,
                status,
                primary_symptom_kind,
                severity,
                started_at,
                last_observed_at,
                recovered_at,
                created_event_id,
                latest_event_id
            FROM abnormal_episodes
            WHERE pet_id = $1::uuid
              AND status <> 'closed'
            ORDER BY started_at DESC, created_at DESC
            LIMIT 1
            "#,
        )
        .bind(pet_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(to_infrastructure_error)
    }

    async fn load_abnormal_episode_initial_event(
        &self,
        event_id: Uuid,
    ) -> PetResult<Option<AbnormalEpisodeEventFactRow>> {
        sqlx::query_as::<_, AbnormalEpisodeEventFactRow>(
            r#"
            SELECT
                e.id AS event_id,
                e.event_subkind,
                e.title,
                e.summary,
                e.occurred_at,
                COALESCE(jsonb_array_length(e.event_payload->'attachment_asset_ids'), 0)::bigint
                    AS attachment_count
            FROM pet_events e
            WHERE e.superseded_by_event_id IS NULL
              AND e.id = $1::uuid
            ORDER BY e.occurred_at ASC, e.created_at ASC
            "#,
        )
        .bind(event_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(to_infrastructure_error)
    }

    async fn load_abnormal_episode_timeline_events(
        &self,
        episode_id: Uuid,
    ) -> PetResult<Vec<AbnormalEpisodeEventFactRow>> {
        sqlx::query_as::<_, AbnormalEpisodeEventFactRow>(
            r#"
            SELECT
                e.id AS event_id,
                e.event_subkind,
                e.title,
                e.summary,
                e.occurred_at,
                COALESCE(jsonb_array_length(e.event_payload->'attachment_asset_ids'), 0)::bigint
                    AS attachment_count
            FROM pet_events e
            WHERE e.superseded_by_event_id IS NULL
              AND (
                e.event_payload->>'episode_id' = $1
                OR e.id = (
                    SELECT created_event_id
                    FROM abnormal_episodes
                    WHERE id = $1::uuid
                )
              )
              AND e.event_subkind IN (
                'abnormal_symptom',
                'symptom_followup',
                'abnormal_recovery',
                'clinic_visit_linked'
              )
            ORDER BY e.occurred_at ASC, e.created_at ASC
            "#,
        )
        .bind(episode_id.to_string())
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)
    }
}
