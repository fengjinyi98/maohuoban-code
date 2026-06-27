use std::sync::Arc;

use async_trait::async_trait;
use maohuoban_ai_application::ai::context::AiFactPackageBuilder;
use maohuoban_ai_application::ai::ports::PetDietFactProvider;
use maohuoban_ai_domain::ai::{
    AiCitation, AiCitationSourceKind, AiError, AiFactEntry, AiFactPackage, AiFactStrength,
    AiPetCandidate, AiPetDisplaySnapshot, AiResult,
};
use maohuoban_pet_application::pet::{
    DietContextItem, PetCurrentDietContext, PetService, RecentDietChangeFact, RecentFeedingFact,
};
use uuid::Uuid;

/// PetServiceDietFactProvider AI 宠物饮食事实适配器
/// 核心职责：
/// - 通过现有 PetService 加载授权当前饮食上下文
/// - 将饮食读模型裁剪为 AI 强事实和引用
#[derive(Clone)]
pub(crate) struct PetServiceDietFactProvider {
    pet: Arc<PetService>,
}

impl PetServiceDietFactProvider {
    /// new 构造饮食事实适配器
    #[must_use]
    pub(crate) fn new(pet: Arc<PetService>) -> Self {
        Self { pet }
    }
}

#[async_trait]
impl PetDietFactProvider for PetServiceDietFactProvider {
    async fn load_current_diet_fact_package(
        &self,
        actor_user_id: Uuid,
        target_pet: &AiPetDisplaySnapshot,
    ) -> AiResult<AiFactPackage> {
        let context = self
            .pet
            .load_pet_current_diet_context(actor_user_id, target_pet.pet_id)
            .await
            .map_err(|error| AiError::Infrastructure(error.to_string()))?;

        Ok(build_diet_fact_package(target_pet, context))
    }
}

/// build_diet_fact_package 构建当前饮食强事实包
/// 核心职责：
/// - 将当前主粮、尝试中、常用零食/营养品映射为强事实
/// - 保留最近喂食和饮食变更引用，供回答引用和审计使用
fn build_diet_fact_package(
    target_pet: &AiPetDisplaySnapshot,
    context: PetCurrentDietContext,
) -> AiFactPackage {
    let candidate = AiPetCandidate {
        pet_id: target_pet.pet_id,
        name: target_pet.pet_name.clone(),
        avatar_url: target_pet.pet_avatar_url.clone(),
        species: target_pet.pet_species.clone(),
        profile_number: target_pet.profile_number.clone(),
    };
    let mut builder = AiFactPackageBuilder::new(&candidate);

    if let Some(item) = context.current_staple {
        add_diet_item_fact(&mut builder, "diet.current_staple", "当前主粮", item);
    }

    for item in context.trying_foods {
        add_diet_item_fact(&mut builder, "diet.trying_food", "尝试中食品", item);
    }
    for item in context.usual_treats {
        add_diet_item_fact(&mut builder, "diet.usual_treat", "常用零食", item);
    }
    for item in context.usual_nutritions {
        add_diet_item_fact(&mut builder, "diet.usual_nutrition", "常用营养品", item);
    }
    for event in &context.recent_feeding_events {
        add_recent_feeding_fact(&mut builder, event);
    }
    for event in &context.recent_diet_changes {
        add_recent_diet_change_fact(&mut builder, event);
    }

    builder.build()
}

/// add_diet_item_fact 添加饮食配置强事实
/// 核心职责：
/// - 保留食品名作为可直接引用事实值
/// - 使用 assignment_id 作为饮食配置引用 ID
fn add_diet_item_fact(
    builder: &mut AiFactPackageBuilder,
    key: &str,
    label: &str,
    item: DietContextItem,
) {
    builder.add_citation(AiCitation {
        source_kind: AiCitationSourceKind::DietAssignment,
        source_id: item.assignment_id,
        label: format!("{label}: {}", item.food_name),
    });
    builder.add_strong_fact(AiFactEntry {
        key: key.to_owned(),
        value: item.food_name,
        strength: AiFactStrength::Strong,
        citation_id: Some(item.assignment_id),
    });
}

/// add_recent_feeding_fact 添加最近喂食强事实
/// 核心职责：
/// - 使用事件 ID 作为引用
/// - 暴露食品名和发生时间供 Prompt 使用
fn add_recent_feeding_fact(builder: &mut AiFactPackageBuilder, event: &RecentFeedingFact) {
    builder.add_citation(AiCitation {
        source_kind: AiCitationSourceKind::PetEvent,
        source_id: event.event_id,
        label: format!("最近喂食: {}", event.food_name),
    });
    builder.add_strong_fact(AiFactEntry {
        key: "diet.recent_feeding".to_owned(),
        value: format!("{} @ {}", event.food_name, event.occurred_at),
        strength: AiFactStrength::Strong,
        citation_id: Some(event.event_id),
    });
}

/// add_recent_diet_change_fact 添加最近饮食变更强事实
/// 核心职责：
/// - 使用事件 ID 作为引用
/// - 暴露变更状态和目标食品 ID，避免虚构食品名
fn add_recent_diet_change_fact(builder: &mut AiFactPackageBuilder, event: &RecentDietChangeFact) {
    builder.add_citation(AiCitation {
        source_kind: AiCitationSourceKind::PetEvent,
        source_id: event.event_id,
        label: "最近饮食变更".to_owned(),
    });
    builder.add_strong_fact(AiFactEntry {
        key: "diet.recent_diet_change".to_owned(),
        value: format!(
            "{} {} -> {}",
            event.event_subkind, event.transition_state, event.to_food_item_id
        ),
        strength: AiFactStrength::Strong,
        citation_id: Some(event.event_id),
    });
}
