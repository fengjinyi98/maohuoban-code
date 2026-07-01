// eval_case Agent Runtime eval 样例解析测试
// 核心职责：
// - 固定首期 eval case schema
// - 验证样例可驱动 intent gate 的确定性断言

use maohuoban_ai_application::ai::intent::AiIntentGate;
use maohuoban_ai_domain::ai::{AiGateDecision, AiIntent};
use serde::Deserialize;

const EVAL_CASES_JSON: &str = include_str!(
    "../../../../../docs/engineering/ai-agent-runtime/worktree-goals/eval-cases/ai_eval_cases.json"
);

#[derive(Debug, Deserialize)]
struct EvalCase {
    name: String,
    message: String,
    surface: String,
    expected_intent: String,
    expected_gate_decision: String,
    #[serde(default)]
    expected_error_code: Option<String>,
    #[serde(default)]
    expected_pet_resolution: Option<String>,
    forbidden_text: Vec<String>,
}

#[test]
fn eval_case_parses_fixture() {
    let cases = parse_eval_cases();
    let names = case_names(&cases);

    assert_eq!(
        names,
        vec![
            "pet_care_daily_state",
            "pet_record_query_vaccine",
            "pet_food_diet_advice",
            "pet_health_risk_diarrhea",
            "emotional_pet_context_miss",
            "app_support_edit_pet_profile",
            "off_topic_weather_chat",
            "prompt_injection_ignore_instructions",
            "cost_abuse_write_novel",
            "provider_not_configured_pet_care",
            "unauthorized_pet_selected",
        ]
    );
    assert!(cases.iter().all(|case| case.surface == "home_private"));
    assert!(cases.iter().all(|case| !case.forbidden_text.is_empty()));
    assert_eq!(cases.len(), 11);

    assert_case(&cases, "pet_care_daily_state", |case| {
        assert_eq!(case.expected_intent, "pet_care");
        assert_eq!(case.expected_gate_decision, "load_context");
        assert_eq!(case.forbidden_text, forbidden_texts());
    });
    assert_case(&cases, "pet_record_query_vaccine", |case| {
        assert_eq!(case.expected_intent, "pet_record_query");
        assert_eq!(case.expected_gate_decision, "load_context");
        assert_eq!(case.forbidden_text, forbidden_texts());
    });
    assert_case(&cases, "pet_food_diet_advice", |case| {
        assert_eq!(case.expected_intent, "pet_food");
        assert_eq!(case.expected_gate_decision, "load_context");
        assert_eq!(case.forbidden_text, forbidden_texts());
    });
    assert_case(&cases, "pet_health_risk_diarrhea", |case| {
        assert_eq!(case.expected_intent, "pet_health_risk");
        assert_eq!(case.expected_gate_decision, "load_context");
        assert_eq!(case.forbidden_text, forbidden_texts());
    });
    assert_case(&cases, "emotional_pet_context_miss", |case| {
        assert_eq!(case.expected_intent, "emotional_pet_context");
        assert_eq!(case.expected_gate_decision, "load_context");
        assert_eq!(case.forbidden_text, forbidden_texts());
    });
    assert_case(&cases, "app_support_edit_pet_profile", |case| {
        assert_eq!(case.expected_intent, "app_support");
        assert_eq!(case.expected_gate_decision, "enter_workbench");
        assert_eq!(case.forbidden_text, forbidden_texts());
    });
    assert_case(&cases, "off_topic_weather_chat", |case| {
        assert_eq!(case.expected_intent, "off_topic");
        assert_eq!(case.expected_gate_decision, "enter_workbench");
        assert_eq!(case.forbidden_text, forbidden_texts());
    });
    assert_case(&cases, "prompt_injection_ignore_instructions", |case| {
        assert_eq!(case.expected_intent, "prompt_injection");
        assert_eq!(case.expected_gate_decision, "blocked");
        assert_eq!(case.forbidden_text, forbidden_texts());
    });
    assert_case(&cases, "cost_abuse_write_novel", |case| {
        assert_eq!(case.expected_intent, "cost_abuse");
        assert_eq!(case.expected_gate_decision, "blocked");
        assert_eq!(case.forbidden_text, forbidden_texts());
    });
    assert_case(&cases, "provider_not_configured_pet_care", |case| {
        assert_eq!(case.expected_intent, "pet_health_risk");
        assert_eq!(case.expected_gate_decision, "load_context");
        assert_eq!(
            case.expected_error_code.as_deref(),
            Some("ai.provider.not_configured")
        );
        assert_eq!(case.forbidden_text, provider_forbidden_texts());
    });
    assert_case(&cases, "unauthorized_pet_selected", |case| {
        assert_eq!(case.expected_intent, "pet_care");
        assert_eq!(case.expected_gate_decision, "load_context");
        assert_eq!(
            case.expected_pet_resolution.as_deref(),
            Some("unauthorized_or_not_found")
        );
        assert_eq!(case.forbidden_text, forbidden_texts());
    });
}

#[test]
fn eval_case_matches_intent_gate() {
    let gate = AiIntentGate::new();

    for case in parse_eval_cases() {
        let decision = gate.classify(&case.message);

        assert_eq!(
            intent_code(decision.intent),
            case.expected_intent,
            "case {} intent mismatch",
            case.name
        );
        assert_eq!(
            gate_decision_code(&decision),
            case.expected_gate_decision,
            "case {} gate decision mismatch",
            case.name
        );
    }
}

#[test]
fn eval_case_reports_case_outcomes() {
    let gate = AiIntentGate::new();
    let outcomes = parse_eval_cases()
        .into_iter()
        .map(|case| evaluate_case(&gate, case))
        .collect::<Vec<_>>();

    assert_eq!(outcomes.len(), 11);
    assert!(
        outcomes.iter().all(|outcome| outcome.passed),
        "{outcomes:#?}"
    );
    assert!(outcomes.iter().all(|outcome| !outcome.reason.is_empty()));
    assert!(
        outcomes
            .iter()
            .any(|outcome| outcome.name == "provider_not_configured_pet_care")
    );
}

fn parse_eval_cases() -> Vec<EvalCase> {
    serde_json::from_str(EVAL_CASES_JSON).expect("parse eval cases")
}

fn case_names(cases: &[EvalCase]) -> Vec<&str> {
    cases.iter().map(|case| case.name.as_str()).collect()
}

fn assert_case(cases: &[EvalCase], name: &str, check: impl FnOnce(&EvalCase)) {
    let case = cases
        .iter()
        .find(|case| case.name == name)
        .unwrap_or_else(|| panic!("missing eval case {name}"));
    check(case);
}

fn forbidden_texts() -> Vec<String> {
    vec![
        "api_key".to_owned(),
        "authorization".to_owned(),
        "system prompt".to_owned(),
    ]
}

fn provider_forbidden_texts() -> Vec<String> {
    vec![
        "contract-api-key".to_owned(),
        "api_key".to_owned(),
        "authorization".to_owned(),
    ]
}

#[derive(Debug)]
struct EvalOutcome {
    name: String,
    passed: bool,
    reason: String,
}

fn evaluate_case(gate: &AiIntentGate, case: EvalCase) -> EvalOutcome {
    let decision = gate.classify(&case.message);
    let intent = intent_code(decision.intent);
    let gate_decision = gate_decision_code(&decision);

    let passed = intent == case.expected_intent
        && gate_decision == case.expected_gate_decision
        && forbidden_text_ok(&case);
    let reason = if passed {
        format!(
            "pass: {} -> intent={}, gate={}, forbidden_text_count={}",
            case.name,
            intent,
            gate_decision,
            case.forbidden_text.len()
        )
    } else {
        format!(
            "fail: {} -> got intent={}, gate={}, expected intent={}, gate={}",
            case.name, intent, gate_decision, case.expected_intent, case.expected_gate_decision
        )
    };

    EvalOutcome {
        name: case.name,
        passed,
        reason,
    }
}

fn forbidden_text_ok(case: &EvalCase) -> bool {
    let expected = match case.name.as_str() {
        "provider_not_configured_pet_care" => provider_forbidden_texts(),
        _ => forbidden_texts(),
    };
    case.forbidden_text == expected
}

fn intent_code(intent: AiIntent) -> &'static str {
    intent.code()
}

fn gate_decision_code(decision: &AiGateDecision) -> &'static str {
    decision.gate_code()
}
