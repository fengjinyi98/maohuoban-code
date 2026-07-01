use maohuoban_ai_domain::ai::{
    AiContentBlock, AiFactEntry, AiFactPackage, AiPetProfileComputedBlock, AiPetProfileFactBlock,
    AiPetProfileNarrativeBlock, AiPetProfileSex, AiPetProfileSpecies,
};

/// project_pet_profile_content_blocks 投影宠物资料 UI 内容块
/// 核心职责：
/// - 从已验证事实包生成前端原生渲染 DTO
/// - 保持事实字段、确定性计算字段和叙事文案分离
pub(super) fn project_pet_profile_content_blocks(package: &AiFactPackage) -> Vec<AiContentBlock> {
    let Some(card) = pet_profile_card_from_package(package) else {
        return Vec::new();
    };
    let pet_name = card.pet.name.clone();
    vec![
        AiContentBlock::SectionHeading {
            id: "pet-profile-heading".to_owned(),
            text: format!("这是{pet_name}的宠物信息"),
        },
        AiContentBlock::PetProfileCard {
            id: "pet-profile-card".to_owned(),
            pet: card.pet,
            computed: card.computed,
            narrative: card.narrative,
        },
    ]
}

struct PetProfileCardProjection {
    pet: AiPetProfileFactBlock,
    computed: AiPetProfileComputedBlock,
    narrative: AiPetProfileNarrativeBlock,
}

fn pet_profile_card_from_package(package: &AiFactPackage) -> Option<PetProfileCardProjection> {
    let target_pet = package.target_pet.as_ref()?;
    let name = fact_value(package, "pet_identity.name")
        .map(ToOwned::to_owned)
        .unwrap_or_else(|| target_pet.pet_name.clone());
    let species = profile_species(&target_pet.pet_species);
    let species_text = fact_value(package, "pet_identity.species")
        .map(ToOwned::to_owned)
        .unwrap_or_else(|| profile_species_text(species).to_owned());
    let sex_text = fact_value(package, "pet_identity.sex")
        .map(ToOwned::to_owned)
        .unwrap_or_else(|| "未知".to_owned());
    let sex = profile_sex(&sex_text);
    let breed = fact_value(package, "pet_identity.breed")
        .map(ToOwned::to_owned)
        .unwrap_or_else(|| "未填写".to_owned());
    let birth_date = fact_value(package, "pet_identity.birthday").map(ToOwned::to_owned);
    let arrival_date = fact_value(package, "pet_identity.arrival_date").map(ToOwned::to_owned);
    let computed = AiPetProfileComputedBlock {
        age_text: computed_value(package, "pet_identity.age_display").map(ToOwned::to_owned),
        companionship_text: computed_value(package, "pet_identity.companionship_display")
            .map(ToOwned::to_owned),
    };
    let narrative = AiPetProfileNarrativeBlock {
        birth: birth_date
            .as_deref()
            .map(|date| format!("{name}在 {date} 来到这个世界，档案里的每一天都值得被好好记住。")),
        arrival: arrival_date
            .as_deref()
            .map(|date| format!("{date} 是{name}到家的日子，这段陪伴已经写进你们的日常里。")),
    };

    Some(PetProfileCardProjection {
        pet: AiPetProfileFactBlock {
            id: target_pet.pet_id.to_string(),
            name,
            species,
            species_text,
            sex,
            sex_text,
            breed,
            avatar_url: target_pet.pet_avatar_url.clone(),
            birth_date,
            arrival_date,
        },
        computed,
        narrative,
    })
}

fn fact_value<'a>(package: &'a AiFactPackage, key: &str) -> Option<&'a str> {
    package
        .facts
        .iter()
        .find(|fact| fact.key == key)
        .map(fact_entry_value)
}

fn computed_value<'a>(package: &'a AiFactPackage, key: &str) -> Option<&'a str> {
    package
        .computed
        .iter()
        .find(|fact| fact.key == key)
        .map(fact_entry_value)
}

fn fact_entry_value(fact: &AiFactEntry) -> &str {
    fact.value.as_str()
}

fn profile_species(species: &str) -> AiPetProfileSpecies {
    match species {
        "cat" | "猫" => AiPetProfileSpecies::Cat,
        "dog" | "狗" => AiPetProfileSpecies::Dog,
        _ => AiPetProfileSpecies::Other,
    }
}

fn profile_species_text(species: AiPetProfileSpecies) -> &'static str {
    match species {
        AiPetProfileSpecies::Cat => "猫",
        AiPetProfileSpecies::Dog => "狗",
        AiPetProfileSpecies::Other => "其他",
    }
}

fn profile_sex(sex_text: &str) -> AiPetProfileSex {
    match sex_text {
        "公猫" | "公犬" | "雄性" | "male" => AiPetProfileSex::Male,
        "母猫" | "母犬" | "雌性" | "female" => AiPetProfileSex::Female,
        _ => AiPetProfileSex::Unknown,
    }
}
