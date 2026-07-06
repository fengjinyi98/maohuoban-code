use std::sync::Arc;

use async_trait::async_trait;
use maohuoban_ai_application::ai::context::AiFactPackageBuilder;
use maohuoban_ai_application::ai::ports::PetAbnormalEpisodeFactProvider;
use maohuoban_ai_domain::ai::{
    AiCitation, AiCitationSourceKind, AiError, AiFactEntry, AiFactPackage, AiFactStrength,
    AiPetCandidate, AiPetDisplaySnapshot, AiResult,
};
use maohuoban_pet_application::pet::{
    PetAbnormalEpisodeEventFact, PetAbnormalEpisodeFacts, PetService,
};
use uuid::Uuid;

/// `PetServiceAbnormalEpisodeFactProvider` AI 异常 episode 事实适配器
/// 核心职责：
/// - 通过 `PetService` 读取授权异常 episode 追踪事实
/// - 将父异常、追加观察、恢复和附件存在性映射为 AI 强事实
#[derive(Clone)]
pub(crate) struct PetServiceAbnormalEpisodeFactProvider {
    pet: Arc<PetService>,
}

impl PetServiceAbnormalEpisodeFactProvider {
    /// new 构造异常 episode 事实适配器
    #[must_use]
    pub(crate) fn new(pet: Arc<PetService>) -> Self {
        Self { pet }
    }
}

#[async_trait]
impl PetAbnormalEpisodeFactProvider for PetServiceAbnormalEpisodeFactProvider {
    async fn load_abnormal_episode_fact_package(
        &self,
        actor_user_id: Uuid,
        target_pet: &AiPetDisplaySnapshot,
        episode_id: Option<Uuid>,
    ) -> AiResult<AiFactPackage> {
        let facts = self
            .pet
            .load_abnormal_episode_facts(actor_user_id, target_pet.pet_id, episode_id)
            .await
            .map_err(|error| AiError::Infrastructure(error.to_string()))?;

        Ok(build_abnormal_episode_fact_package(
            target_pet,
            facts.as_ref(),
        ))
    }
}

/// `build_abnormal_episode_fact_package` 构建异常 episode 事实包
/// 核心职责：
/// - 只输出异常 episode 相关事实
/// - 保留 episode 与 pet event 引用供回答引用和审计使用
fn build_abnormal_episode_fact_package(
    target_pet: &AiPetDisplaySnapshot,
    facts: Option<&PetAbnormalEpisodeFacts>,
) -> AiFactPackage {
    let candidate = AiPetCandidate {
        pet_id: target_pet.pet_id,
        name: target_pet.pet_name.clone(),
        avatar_url: target_pet.pet_avatar_url.clone(),
        species: target_pet.pet_species.clone(),
        profile_number: target_pet.profile_number.clone(),
    };
    let mut builder = AiFactPackageBuilder::new(&candidate);

    let Some(facts) = facts else {
        builder.add_strong_fact(AiFactEntry {
            key: "health.abnormal_episode.status".to_owned(),
            value: "没有可读取的异常 episode".to_owned(),
            strength: AiFactStrength::Strong,
            citation_id: None,
        });
        return builder.build();
    };

    builder.add_citation(AiCitation {
        source_kind: AiCitationSourceKind::AbnormalEpisode,
        source_id: facts.episode_id,
        label: format!(
            "异常 episode：{}，开始于 {}",
            facts.status, facts.started_at
        ),
    });
    add_status_fact(&mut builder, facts);
    add_initial_event_fact(&mut builder, facts);
    add_timeline_facts(&mut builder, facts);
    add_attachment_fact(&mut builder, facts);
    add_followup_gap_fact(&mut builder, facts);

    builder.build()
}

/// `add_status_fact` 添加异常 episode 状态事实
/// 核心职责：
/// - 暴露 episode 状态、症状、严重程度和恢复时间
fn add_status_fact(builder: &mut AiFactPackageBuilder, facts: &PetAbnormalEpisodeFacts) {
    builder.add_strong_fact(AiFactEntry {
        key: "health.abnormal_episode.status".to_owned(),
        value: format!(
            "episode_id={} status={} primary_symptom={} severity={} started_at={} recovered_at={}",
            facts.episode_id,
            facts.status,
            facts.primary_symptom_kind.as_deref().unwrap_or("unknown"),
            facts.severity.as_deref().unwrap_or("unknown"),
            facts.started_at,
            facts
                .recovered_at
                .map_or_else(|| "none".to_owned(), |value| value.to_string())
        ),
        strength: AiFactStrength::Strong,
        citation_id: Some(facts.episode_id),
    });
}

/// `add_initial_event_fact` 添加父异常记录事实
/// 核心职责：
/// - 暴露父异常标题、摘要、发生时间和附件数量
fn add_initial_event_fact(builder: &mut AiFactPackageBuilder, facts: &PetAbnormalEpisodeFacts) {
    add_event_citation(builder, &facts.initial_event);
    builder.add_strong_fact(AiFactEntry {
        key: "health.abnormal_episode.initial_event".to_owned(),
        value: event_fact_value(&facts.initial_event),
        strength: AiFactStrength::Strong,
        citation_id: Some(facts.initial_event.event_id),
    });
}

/// `add_timeline_facts` 添加进展时间线事实
/// 核心职责：
/// - 暴露同 episode 的父事件、追加观察、恢复和就诊关联序列
fn add_timeline_facts(builder: &mut AiFactPackageBuilder, facts: &PetAbnormalEpisodeFacts) {
    for event in &facts.timeline_events {
        add_event_citation(builder, event);
        builder.add_strong_fact(AiFactEntry {
            key: "health.abnormal_episode.timeline".to_owned(),
            value: event_fact_value(event),
            strength: AiFactStrength::Strong,
            citation_id: Some(event.event_id),
        });
    }
}

/// `add_attachment_fact` 添加附件存在性事实
/// 核心职责：
/// - 统计 episode 内父异常和追加观察是否带照片附件
fn add_attachment_fact(builder: &mut AiFactPackageBuilder, facts: &PetAbnormalEpisodeFacts) {
    let total = facts
        .timeline_events
        .iter()
        .map(|event| event.attachment_count)
        .sum::<i64>();
    builder.add_strong_fact(AiFactEntry {
        key: "health.abnormal_episode.attachments".to_owned(),
        value: format!("attachment_count={total}"),
        strength: AiFactStrength::Strong,
        citation_id: Some(facts.episode_id),
    });
}

/// `add_followup_gap_fact` 添加追踪间隔事实
/// 核心职责：
/// - 暴露最近一次进展时间，供 Agent 判断是否需要继续追踪
fn add_followup_gap_fact(builder: &mut AiFactPackageBuilder, facts: &PetAbnormalEpisodeFacts) {
    let latest_time = facts
        .timeline_events
        .last()
        .map_or(facts.started_at, |event| event.occurred_at);
    builder.add_strong_fact(AiFactEntry {
        key: "health.abnormal_episode.followup_gap".to_owned(),
        value: format!("latest_observed_at={latest_time}"),
        strength: AiFactStrength::Strong,
        citation_id: facts.latest_event_id.or(Some(facts.created_event_id)),
    });
}

/// `add_event_citation` 添加 pet event 引用
/// 核心职责：
/// - 为异常事件事实提供可追溯引用
fn add_event_citation(builder: &mut AiFactPackageBuilder, event: &PetAbnormalEpisodeEventFact) {
    builder.add_citation(AiCitation {
        source_kind: AiCitationSourceKind::PetEvent,
        source_id: event.event_id,
        label: format!(
            "{}: {}",
            event.title,
            event.summary.as_deref().unwrap_or("无摘要")
        ),
    });
}

/// `event_fact_value` 格式化异常事件事实
/// 核心职责：
/// - 将单个异常事件转成稳定文本事实
fn event_fact_value(event: &PetAbnormalEpisodeEventFact) -> String {
    format!(
        "event_id={} subkind={} title={} summary={} occurred_at={} attachment_count={}",
        event.event_id,
        event.event_subkind.as_deref().unwrap_or("unknown"),
        event.title,
        event.summary.as_deref().unwrap_or("无摘要"),
        event.occurred_at,
        event.attachment_count
    )
}
