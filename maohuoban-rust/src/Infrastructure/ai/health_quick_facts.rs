use std::sync::Arc;

use async_trait::async_trait;
use maohuoban_ai_application::ai::context::AiFactPackageBuilder;
use maohuoban_ai_application::ai::ports::PetHealthQuickFactProvider;
use maohuoban_ai_domain::ai::{
    AiCitation, AiCitationSourceKind, AiError, AiFactEntry, AiFactPackage, AiFactStrength,
    AiPetCandidate, AiPetDisplaySnapshot, AiResult,
};
use maohuoban_pet_application::pet::{PetRecentHealthFacts, PetService, RecentHealthQuickFact};
use uuid::Uuid;

/// `PetServiceHealthQuickFactProvider` AI 宠物健康快捷事实适配器
/// 核心职责：
/// - 通过现有 `PetService` 加载授权健康 quick fact
/// - 将 quick fact 读模型裁剪为 AI 强事实和引用
#[derive(Clone)]
pub(crate) struct PetServiceHealthQuickFactProvider {
    pet: Arc<PetService>,
}

impl PetServiceHealthQuickFactProvider {
    /// new 构造健康快捷事实适配器
    #[must_use]
    pub(crate) fn new(pet: Arc<PetService>) -> Self {
        Self { pet }
    }
}

#[async_trait]
impl PetHealthQuickFactProvider for PetServiceHealthQuickFactProvider {
    async fn load_recent_health_quick_fact_package(
        &self,
        actor_user_id: Uuid,
        target_pet: &AiPetDisplaySnapshot,
    ) -> AiResult<AiFactPackage> {
        let facts = self
            .pet
            .load_recent_health_quick_facts(actor_user_id, target_pet.pet_id, 20)
            .await
            .map_err(|error| AiError::Infrastructure(error.to_string()))?;

        Ok(build_health_quick_fact_package(target_pet, &facts))
    }
}

/// `build_health_quick_fact_package` 构建健康快捷事实包
/// 核心职责：
/// - 将便便、精神、食欲快捷记录映射为强事实
/// - 保留 pet event 引用供回答引用和审计使用
fn build_health_quick_fact_package(
    target_pet: &AiPetDisplaySnapshot,
    facts: &PetRecentHealthFacts,
) -> AiFactPackage {
    let candidate = AiPetCandidate {
        pet_id: target_pet.pet_id,
        name: target_pet.pet_name.clone(),
        avatar_url: target_pet.pet_avatar_url.clone(),
        species: target_pet.pet_species.clone(),
        profile_number: target_pet.profile_number.clone(),
    };
    let mut builder = AiFactPackageBuilder::new(&candidate);

    for fact in &facts.quick_facts {
        add_health_quick_fact(&mut builder, fact);
    }

    builder.build()
}

/// `add_health_quick_fact` 添加健康快捷强事实
/// 核心职责：
/// - 使用事件 ID 作为引用
/// - 暴露标题、摘要、类型和发生时间供 Prompt 使用
fn add_health_quick_fact(builder: &mut AiFactPackageBuilder, fact: &RecentHealthQuickFact) {
    let summary = fact.summary.as_deref().unwrap_or("无摘要");
    builder.add_citation(AiCitation {
        source_kind: AiCitationSourceKind::PetEvent,
        source_id: fact.event_id,
        label: format!("{}: {summary}", fact.title),
    });
    builder.add_strong_fact(AiFactEntry {
        key: "health.recent_quick_fact".to_owned(),
        value: format!(
            "{}（{}）：{} @ {}",
            fact.title, fact.quick_fact_kind, summary, fact.occurred_at
        ),
        strength: AiFactStrength::Strong,
        citation_id: Some(fact.event_id),
    });
}
