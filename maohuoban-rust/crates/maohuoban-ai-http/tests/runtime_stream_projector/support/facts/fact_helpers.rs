use maohuoban_ai_domain::ai::{AiFactEntry, AiFactPackage, AiFactStrength, AiPetCandidate};
use uuid::Uuid;

pub fn identity_fact_package(name: &str) -> AiFactPackage {
    let mut package = AiFactPackage::empty();
    let candidate = AiPetCandidate {
        pet_id: Uuid::new_v4(),
        name: name.to_owned(),
        avatar_url: Some("/uploads/pets/meilu.png".to_owned()),
        species: "cat".to_owned(),
        profile_number: "P001".to_owned(),
    };
    package.target_pet = Some((&candidate).into());
    package.facts = vec![
        strong_fact("pet_identity.name", name),
        strong_fact("pet_identity.species", "猫"),
        strong_fact("pet_identity.sex", "母猫"),
        strong_fact("pet_identity.breed", "英短"),
        strong_fact("pet_identity.birthday", "2024-06-17"),
        strong_fact("pet_identity.arrival_date", "2025-06-17"),
    ];
    package.computed = vec![
        strong_fact("pet_identity.age_display", "当前年龄约 2岁15天"),
        strong_fact("pet_identity.companionship_display", "到家陪伴 380 天"),
    ];
    package.fact_strength = AiFactStrength::Strong;
    package
}

pub fn diet_fact_package(name: &str) -> AiFactPackage {
    let mut package = AiFactPackage::empty();
    let candidate = AiPetCandidate {
        pet_id: Uuid::new_v4(),
        name: name.to_owned(),
        avatar_url: Some("/uploads/pets/meilu.png".to_owned()),
        species: "cat".to_owned(),
        profile_number: "P001".to_owned(),
    };
    package.target_pet = Some((&candidate).into());
    package.facts = vec![strong_fact("diet.current_staple", "渴望六种鱼全期猫粮")];
    package.fact_strength = AiFactStrength::Strong;
    package
}

fn strong_fact(key: &str, value: &str) -> AiFactEntry {
    AiFactEntry {
        key: key.to_owned(),
        value: value.to_owned(),
        strength: AiFactStrength::Strong,
        citation_id: None,
    }
}
