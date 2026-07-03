use maohuoban_ai_domain::ai::{AiFactEntry, AiFactPackage, AiFactStrength, AiPetCandidate};
use uuid::Uuid;

/// `identity_fact_package` 构造宠物身份事实包
/// 核心职责：
/// - 固定目标宠物和强事实
/// - 验证工具结果向 runtime 投影时保留 typed fact package
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
        AiFactEntry {
            key: "pet_identity.name".to_owned(),
            value: name.to_owned(),
            strength: AiFactStrength::Strong,
            citation_id: None,
        },
        AiFactEntry {
            key: "pet_identity.species".to_owned(),
            value: "猫".to_owned(),
            strength: AiFactStrength::Strong,
            citation_id: None,
        },
    ];
    package.computed = vec![AiFactEntry {
        key: "pet_identity.age_display".to_owned(),
        value: "当前年龄约 2岁15天".to_owned(),
        strength: AiFactStrength::Strong,
        citation_id: None,
    }];
    package.fact_strength = AiFactStrength::Strong;
    package
}

/// `mixed_strength_fact_package` 构造混合强度事实包
/// 核心职责：
/// - 固定待确认事实和弱线索
/// - 验证模型可见文本保留确定性标签并隐藏内部字段
pub fn mixed_strength_fact_package() -> AiFactPackage {
    let mut package = AiFactPackage::empty();
    package.pending_confirmations = vec![AiFactEntry {
        key: "diet.confirmation_candidate".to_owned(),
        value:
            "food_inventory_added main_food: 最近新增的「渴望六种鱼」，饭团有吃过或正在换这款吗？"
                .to_owned(),
        strength: AiFactStrength::PendingConfirmation,
        citation_id: None,
    }];
    package.weak_hints = vec![AiFactEntry {
        key: "food_inventory.change_hint".to_owned(),
        value: "added wet_food: 巅峰牛肉罐头".to_owned(),
        strength: AiFactStrength::Weak,
        citation_id: None,
    }];
    package.fact_strength = AiFactStrength::PendingConfirmation;
    package
}
