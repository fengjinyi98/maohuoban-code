use std::sync::Arc;

use async_trait::async_trait;
use maohuoban_ai_application::ai::context::AiFactPackageBuilder;
use maohuoban_ai_application::ai::ports::PetIdentityFactProvider;
use maohuoban_ai_domain::ai::{
    AiError, AiFactEntry, AiFactPackage, AiFactStrength, AiPetCandidate, AiPetDisplaySnapshot,
    AiResult,
};
use maohuoban_pet_application::pet::PetService;
use maohuoban_pet_domain::pet::IdentitySummary;
use uuid::Uuid;

/// `PetServiceIdentityFactProvider` AI 宠物身份事实适配器
/// 核心职责：
/// - 通过现有 `PetService` 加载授权身份上下文
/// - 将宠物身份摘要裁剪为 AI 强事实包
#[derive(Clone)]
pub(crate) struct PetServiceIdentityFactProvider {
    pet: Arc<PetService>,
}

impl PetServiceIdentityFactProvider {
    /// new 构造身份事实适配器
    #[must_use]
    pub(crate) fn new(pet: Arc<PetService>) -> Self {
        Self { pet }
    }
}

#[async_trait]
impl PetIdentityFactProvider for PetServiceIdentityFactProvider {
    async fn load_identity_fact_package(
        &self,
        actor_user_id: Uuid,
        target_pet: &AiPetDisplaySnapshot,
    ) -> AiResult<AiFactPackage> {
        let context = self
            .pet
            .load_identity_context(actor_user_id, target_pet.pet_id)
            .await
            .map_err(|error| AiError::Infrastructure(error.to_string()))?;

        let candidate = AiPetCandidate {
            pet_id: target_pet.pet_id,
            name: context.identity.name.clone(),
            avatar_url: target_pet.pet_avatar_url.clone(),
            species: context.identity.species.clone(),
            profile_number: context.identity.profile_number.clone(),
        };
        let mut builder = AiFactPackageBuilder::new(&candidate);
        for fact in identity_facts_for_prompt(&context.identity) {
            builder.add_strong_fact(fact);
        }
        Ok(builder.build())
    }
}

/// `identity_facts_for_prompt` 构造可进入普通回答的身份事实
/// 核心职责：
/// - 只保留用户视角的基础档案字段
/// - 将内部枚举值转换为自然中文展示值
fn identity_facts_for_prompt(identity: &IdentitySummary) -> Vec<AiFactEntry> {
    let mut facts = vec![
        identity_fact("pet_identity.name", identity.name.clone()),
        identity_fact(
            "pet_identity.species",
            display_species(&identity.species).to_owned(),
        ),
        identity_fact(
            "pet_identity.sex",
            display_sex(&identity.species, &identity.sex).to_owned(),
        ),
    ];

    if let Some(breed) = &identity.breed {
        facts.push(identity_fact("pet_identity.breed", breed.clone()));
    }
    if let Some(birthday) = &identity.birthday {
        facts.push(identity_fact("pet_identity.birthday", birthday.clone()));
    }
    if let Some(arrival_date) = &identity.arrival_date {
        facts.push(identity_fact(
            "pet_identity.arrival_date",
            arrival_date.clone(),
        ));
    }
    if let Some(world_days) = identity.world_days {
        facts.push(identity_fact(
            "pet_identity.world_days",
            format!("来到世界的第 {world_days} 天"),
        ));
    }
    if let Some(companionship_days) = identity.companionship_days {
        facts.push(identity_fact(
            "pet_identity.companionship_days",
            format!("已陪伴 {companionship_days} 天"),
        ));
    }

    facts
}

/// `identity_fact` 构造身份强事实
/// 核心职责：
/// - 统一身份事实 key 和强度
fn identity_fact(key: &str, value: String) -> AiFactEntry {
    AiFactEntry {
        key: key.to_owned(),
        value,
        strength: AiFactStrength::Strong,
        citation_id: None,
    }
}

/// `display_species` 返回身份事实里的宠物物种展示值
/// 核心职责：
/// - 屏蔽数据库枚举值
/// - 保留未知扩展值的信息量
fn display_species(species: &str) -> &str {
    match species {
        "cat" => "猫",
        "dog" => "狗",
        "other" => "其他",
        value => value,
    }
}

/// `display_sex` 返回身份事实里的宠物性别展示值
/// 核心职责：
/// - 按物种输出自然中文
/// - 对未知扩展值保持原值，避免丢失信息
fn display_sex<'a>(species: &str, sex: &'a str) -> &'a str {
    match (species, sex) {
        ("cat", "female") => "母猫",
        ("cat", "male") => "公猫",
        ("dog", "female") => "母犬",
        ("dog", "male") => "公犬",
        (_, "female") => "雌性",
        (_, "male") => "雄性",
        (_, "unknown") => "未知",
        (_, value) => value,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_identity() -> IdentitySummary {
        IdentitySummary {
            pet_id: Uuid::new_v4(),
            profile_number: "P001".to_owned(),
            name: "测试名字1".to_owned(),
            species: "cat".to_owned(),
            breed: Some("英短".to_owned()),
            sex: "female".to_owned(),
            birthday: Some("2024-06-17".to_owned()),
            arrival_date: Some("2024-08-01".to_owned()),
            world_days: Some(379),
            companionship_days: Some(334),
            life_status: "alive".to_owned(),
        }
    }

    #[test]
    fn identity_facts_for_prompt_excludes_life_status() {
        let facts = identity_facts_for_prompt(&sample_identity());

        assert!(
            facts
                .iter()
                .all(|fact| fact.key != "pet_identity.life_status"),
            "普通身份事实不应把生命周期状态交给模型展示"
        );
    }

    #[test]
    fn identity_facts_for_prompt_localizes_enum_values() {
        let facts = identity_facts_for_prompt(&sample_identity());
        let value_for = |key: &str| {
            facts
                .iter()
                .find(|fact| fact.key == key)
                .map(|fact| fact.value.as_str())
        };

        assert_eq!(value_for("pet_identity.species"), Some("猫"));
        assert_eq!(value_for("pet_identity.sex"), Some("母猫"));
        assert_eq!(value_for("pet_identity.birthday"), Some("2024-06-17"));
        assert_eq!(value_for("pet_identity.arrival_date"), Some("2024-08-01"));
        assert_eq!(
            value_for("pet_identity.world_days"),
            Some("来到世界的第 379 天")
        );
        assert_eq!(
            value_for("pet_identity.companionship_days"),
            Some("已陪伴 334 天")
        );
        assert!(facts.iter().all(|fact| fact.value != "cat"));
        assert!(facts.iter().all(|fact| fact.value != "female"));
    }
}
