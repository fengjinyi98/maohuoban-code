// answer_verifier AiAnswerVerifier 测试
// 核心职责：
// - 验证无来源事实被拦截
// - 验证弱线索误用被拦截
// - 验证医疗诊断被拦截
// - 遵循 TDD：先写失败测试（red），再实现校验器（green）

use maohuoban_ai_application::ai::verifier::{AiAnswerVerificationContext, AiAnswerVerifier};
use maohuoban_ai_domain::ai::{AiBlockedReason, AiFactEntry, AiFactPackage, AiFactStrength};

fn package_with_only_weak_hint() -> AiFactPackage {
    let mut package = AiFactPackage::empty();
    package.weak_hints.push(AiFactEntry {
        key: "inventory_new_food".to_owned(),
        value: "新增主粮: 渴望六种鱼".to_owned(),
        strength: AiFactStrength::Weak,
        citation_id: None,
    });
    package.missing_info.push("尚未配置当前主粮".to_owned());
    package
}

fn package_with_strong_staple() -> AiFactPackage {
    let mut package = AiFactPackage::empty();
    package.facts.push(AiFactEntry {
        key: "current_staple".to_owned(),
        value: "渴望六种鱼".to_owned(),
        strength: AiFactStrength::Strong,
        citation_id: None,
    });
    package.fact_strength = AiFactStrength::Strong;
    package
}

fn package_with_pet_age_facts() -> AiFactPackage {
    let mut package = AiFactPackage::empty();
    package.facts.push(AiFactEntry {
        key: "pet_identity.birthday".to_owned(),
        value: "2025-05-06".to_owned(),
        strength: AiFactStrength::Strong,
        citation_id: None,
    });
    package.facts.push(AiFactEntry {
        key: "pet_identity.world_days".to_owned(),
        value: "420".to_owned(),
        strength: AiFactStrength::Strong,
        citation_id: None,
    });
    package.fact_strength = AiFactStrength::Strong;
    package
}

#[test]
fn weak_hint_misuse_blocked() {
    let package = package_with_only_weak_hint();
    let verifier = AiAnswerVerifier::new();
    // 回答说"已经换粮"，但事实包只有弱线索"新增主粮"
    let result = verifier.verify("毛球已经换粮了，现在吃渴望六种鱼", &package);
    assert!(result.is_blocked());
    assert_eq!(result.blocked_reason, Some(AiBlockedReason::WeakHintMisuse));
}

#[test]
fn unsupported_medication_fact_no_longer_blocked_by_verifier() {
    let package = package_with_strong_staple();
    let verifier = AiAnswerVerifier::new();
    let result = verifier.verify("毛球吃了阿莫西林效果好", &package);
    assert!(
        !result.is_blocked(),
        "药物名词表拦截已退役，应交给模型安全指令和 eval 红线组"
    );
}

#[test]
fn medical_diagnosis_like_text_no_longer_blocked_by_verifier() {
    let package = package_with_strong_staple();
    let verifier = AiAnswerVerifier::new();
    let result = verifier.verify("毛球得了肠胃炎，需要吃甲硝唑", &package);
    assert!(
        !result.is_blocked(),
        "医疗越界表达不再由 verifier 词表拦截，应交给模型指令与 eval 红线组治理"
    );
}

#[test]
fn safe_answer_with_strong_facts_passes() {
    let package = package_with_strong_staple();
    let verifier = AiAnswerVerifier::new();
    let result = verifier.verify("毛球当前的主粮是渴望六种鱼，营养均衡", &package);
    assert!(!result.is_blocked());
    assert_eq!(
        result.status,
        maohuoban_ai_domain::ai::AiVerificationStatus::Passed
    );
}

#[test]
fn safe_answer_about_missing_info_passes() {
    let package = package_with_only_weak_hint();
    let verifier = AiAnswerVerifier::new();
    let result = verifier.verify(
        "目前还没有确认毛球的主粮配置，需要您确认后才能给出建议",
        &package,
    );
    assert!(!result.is_blocked());
}

#[test]
fn blocked_result_has_safe_fallback() {
    let package = package_with_only_weak_hint();
    let verifier = AiAnswerVerifier::new();
    let result = verifier.verify("毛球已经换粮了", &package);
    assert!(result.is_blocked());
    assert!(result.safe_fallback_text.is_some());
    assert!(result.retry_suggestion.is_some());
}

#[test]
fn unconfirmed_write_blocked() {
    let package = package_with_strong_staple();
    let verifier = AiAnswerVerifier::new();
    // 回答声称已经执行了写操作
    let result = verifier.verify("我已经帮毛球换了新粮并设置了喂食计划", &package);
    assert!(result.is_blocked());
    assert_eq!(
        result.blocked_reason,
        Some(AiBlockedReason::UnconfirmedWrite)
    );
}

#[test]
fn pet_profile_update_claim_without_tool_success_blocked() {
    let package = package_with_strong_staple();
    let verifier = AiAnswerVerifier::new();
    let result = verifier.verify(
        "宠物名已成功更新为梅鹿，现在档案中记录的是正确版本。",
        &package,
    );

    assert!(result.is_blocked());
    assert_eq!(
        result.blocked_reason,
        Some(AiBlockedReason::UnconfirmedWrite)
    );
}

#[test]
fn missing_age_or_birthday_claim_conflicts_with_identity_facts() {
    let package = package_with_pet_age_facts();
    let verifier = AiAnswerVerifier::new();
    let result = verifier.verify("目前档案里没有生日记录，所以还不知道梅录多大。", &package);

    assert!(result.is_blocked());
    assert_eq!(
        result.blocked_reason,
        Some(AiBlockedReason::UnsupportedFact)
    );
}

#[test]
fn missing_age_or_birthday_claim_without_identity_tool_success_blocked() {
    let package = AiFactPackage::empty();
    let verifier = AiAnswerVerifier::new();
    let context = AiAnswerVerificationContext {
        identity_context_tool_required: true,
        identity_context_tool_succeeded: false,
        successful_write_tools: Vec::new(),
    };

    let result = verifier.verify_with_context(
        "目前档案里没有生日记录，所以还不知道梅录多大。",
        &package,
        context,
    );

    assert!(result.is_blocked());
    assert_eq!(
        result.blocked_reason,
        Some(AiBlockedReason::UnsupportedFact)
    );
}

#[test]
fn compliant_medical_escalation_text_passes() {
    let package = package_with_strong_staple();
    let verifier = AiAnswerVerifier::new();
    let result = verifier.verify(
        "我不能做诊断，建议继续观察精神和食欲变化，并尽快带毛球去医院由医生判断。",
        &package,
    );

    assert!(!result.is_blocked(), "合规转诊表述不应被医疗词表误伤");
}

#[test]
fn write_completion_claim_requires_successful_write_evidence() {
    let package = package_with_strong_staple();
    let verifier = AiAnswerVerifier::new();

    let no_write_evidence = verifier.verify("我已经帮你记录了今天的拉稀情况。", &package);
    assert!(no_write_evidence.is_blocked());
    assert_eq!(
        no_write_evidence.blocked_reason,
        Some(AiBlockedReason::UnconfirmedWrite)
    );
}

#[test]
fn write_completion_claim_passes_with_successful_write_evidence() {
    let package = package_with_strong_staple();
    let verifier = AiAnswerVerifier::new();
    let context = AiAnswerVerificationContext {
        identity_context_tool_required: false,
        identity_context_tool_succeeded: false,
        successful_write_tools: vec!["record_pet_observation".to_owned()],
    };

    let result =
        verifier.verify_with_context("我已经帮你记录了今天的拉稀情况。", &package, context);
    assert!(
        !result.is_blocked(),
        "成功写工具证据存在时，写完成声明应通过 verifier"
    );
}
