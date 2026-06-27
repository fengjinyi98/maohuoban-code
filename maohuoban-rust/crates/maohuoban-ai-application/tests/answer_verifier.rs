// answer_verifier AiAnswerVerifier 测试
// 核心职责：
// - 验证无来源事实被拦截
// - 验证弱线索误用被拦截
// - 验证医疗诊断被拦截
// - 遵循 TDD：先写失败测试（red），再实现校验器（green）

use maohuoban_ai_application::ai::verifier::AiAnswerVerifier;
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
fn unsupported_fact_blocked() {
    let package = package_with_strong_staple();
    let verifier = AiAnswerVerifier::new();
    // 回答提到了事实包中不存在的药物
    let result = verifier.verify("毛球吃了阿莫西林效果好", &package);
    assert!(result.is_blocked());
    assert_eq!(
        result.blocked_reason,
        Some(AiBlockedReason::UnsupportedFact)
    );
}

#[test]
fn medical_diagnosis_blocked() {
    let package = package_with_strong_staple();
    let verifier = AiAnswerVerifier::new();
    // 回答做了诊断
    let result = verifier.verify("毛球得了肠胃炎，需要吃甲硝唑", &package);
    assert!(result.is_blocked());
    assert!(matches!(
        result.blocked_reason,
        Some(AiBlockedReason::MedicalBlocked)
    ));
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
