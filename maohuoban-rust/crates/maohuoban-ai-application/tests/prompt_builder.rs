// prompt_builder AiPromptBuilder 测试
// 核心职责：
// - 验证生成的 prompt messages 只包含系统规则、用户问题、宠物候选、授权事实包和输出格式
// - 断言不包含 API key、actor token、审计表原文
// - 遵循 TDD：先写失败测试（red），再实现 Prompt Builder（green）

use maohuoban_ai_application::ai::prompt::AiPromptBuilder;
use maohuoban_ai_domain::ai::{
    AiCitation, AiCitationSourceKind, AiFactEntry, AiFactPackage, AiFactStrength, AiPetCandidate,
    AiPetDisplaySnapshot, LlmRole,
};
use uuid::Uuid;

fn pet_candidate(name: &str) -> AiPetCandidate {
    AiPetCandidate {
        pet_id: Uuid::new_v4(),
        name: name.to_owned(),
        avatar_url: None,
        species: "cat".to_owned(),
        profile_number: "P001".to_owned(),
    }
}

fn fact_package(pet: &AiPetCandidate) -> AiFactPackage {
    let mut package = AiFactPackage::empty();
    package.target_pet = Some(AiPetDisplaySnapshot::from(pet));
    package.facts.push(AiFactEntry {
        key: "current_staple".to_owned(),
        value: "渴望六种鱼".to_owned(),
        strength: AiFactStrength::Strong,
        citation_id: Some(Uuid::new_v4()),
    });
    package.weak_hints.push(AiFactEntry {
        key: "inventory_hint".to_owned(),
        value: "新增零食".to_owned(),
        strength: AiFactStrength::Weak,
        citation_id: None,
    });
    package.citations.push(AiCitation {
        source_kind: AiCitationSourceKind::DietAssignment,
        source_id: Uuid::new_v4(),
        label: "当前主粮".to_owned(),
    });
    package.missing_info.push("尚未确认换粮".to_owned());
    package.fact_strength = AiFactStrength::Strong;
    package
}

#[test]
fn prompt_contains_system_rules_and_user_question() {
    let pet = pet_candidate("毛球");
    let package = fact_package(&pet);
    let builder = AiPromptBuilder::new();
    let messages = builder.build_messages(
        "毛球今天拉肚子了",
        std::slice::from_ref(&pet),
        Some(&package),
    );

    // 第一条是 system message
    assert_eq!(messages[0].role, LlmRole::System);
    assert!(messages[0].content.contains("毛球"));
    // 最后一条是 user message
    let last = messages.last().expect("should have user message");
    assert_eq!(last.role, LlmRole::User);
    assert!(last.content.contains("拉肚子"));
}

#[test]
fn prompt_includes_strong_facts() {
    let pet = pet_candidate("毛球");
    let package = fact_package(&pet);
    let builder = AiPromptBuilder::new();
    let messages = builder.build_messages("毛球怎么样", std::slice::from_ref(&pet), Some(&package));

    let all_content: String = messages.iter().map(|m| m.content.as_str()).collect();
    assert!(
        all_content.contains("渴望六种鱼"),
        "strong fact should be in prompt"
    );
}

#[test]
fn prompt_includes_weak_hints_as_hints_not_facts() {
    let pet = pet_candidate("毛球");
    let package = fact_package(&pet);
    let builder = AiPromptBuilder::new();
    let messages = builder.build_messages("毛球怎么样", std::slice::from_ref(&pet), Some(&package));

    let all_content: String = messages.iter().map(|m| m.content.as_str()).collect();
    assert!(
        all_content.contains("新增零食"),
        "weak hint should be in prompt"
    );
    assert!(
        all_content.contains("弱线索")
            || all_content.contains("hint")
            || all_content.contains("待确认"),
        "weak hints should be labeled as hints"
    );
}

#[test]
fn prompt_excludes_api_key_and_tokens() {
    let pet = pet_candidate("毛球");
    let package = fact_package(&pet);
    let builder = AiPromptBuilder::new();
    let messages = builder.build_messages("毛球怎么样", std::slice::from_ref(&pet), Some(&package));

    let all_content: String = messages.iter().map(|m| m.content.as_str()).collect();
    assert!(!all_content.contains("Bearer"), "no API key in prompt");
    assert!(!all_content.contains("sk-"), "no API key prefix in prompt");
    assert!(
        !all_content.contains("api_key"),
        "no api_key field in prompt"
    );
    assert!(
        !all_content.contains("actor_user_id"),
        "no actor user id in prompt"
    );
    assert!(
        !all_content.contains("authorization"),
        "no auth header in prompt"
    );
}

#[test]
fn prompt_includes_pet_candidates_when_multiple() {
    let pet1 = pet_candidate("毛球");
    let pet2 = pet_candidate("豆豆");
    let package = fact_package(&pet1);
    let builder = AiPromptBuilder::new();
    let messages =
        builder.build_messages("毛球怎么样", &[pet1.clone(), pet2.clone()], Some(&package));

    let all_content: String = messages.iter().map(|m| m.content.as_str()).collect();
    assert!(
        all_content.contains("毛球"),
        "pet1 name should be in candidates"
    );
    assert!(
        all_content.contains("豆豆"),
        "pet2 name should be in candidates"
    );
}

#[test]
fn prompt_works_without_fact_package() {
    let pet = pet_candidate("毛球");
    let builder = AiPromptBuilder::new();
    let messages = builder.build_messages("你好", std::slice::from_ref(&pet), None);

    assert!(!messages.is_empty());
    assert_eq!(messages.last().expect("user msg").role, LlmRole::User);
}

#[test]
fn prompt_includes_missing_info() {
    let pet = pet_candidate("毛球");
    let package = fact_package(&pet);
    let builder = AiPromptBuilder::new();
    let messages = builder.build_messages("毛球怎么样", std::slice::from_ref(&pet), Some(&package));

    let all_content: String = messages.iter().map(|m| m.content.as_str()).collect();
    assert!(
        all_content.contains("尚未确认换粮"),
        "missing info should be in prompt"
    );
}
