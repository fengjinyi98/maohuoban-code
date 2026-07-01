// eval_case Agent Runtime eval 样例解析测试
// 核心职责：
// - 固定首期 eval case schema
// - 验证样例可驱动 intent gate 的确定性断言

use maohuoban_ai_application::ai::intent::AiIntentGate;
use maohuoban_ai_domain::ai::{AiGateDecision, AiIntent};
use serde::Deserialize;
use std::collections::BTreeSet;

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
    expected_workbench: String,
    expected_context_loaded: bool,
    expected_enters_workbench: bool,
    expected_terminal_state: String,
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
    assert_eq!(
        value_set(&cases, |case| case.expected_workbench.as_str()),
        BTreeSet::from(["blocked", "light_response", "private_pet_context"])
    );
    assert_eq!(
        value_set(&cases, |case| case.expected_terminal_state.as_str()),
        BTreeSet::from(["blocked", "completed", "failed"])
    );

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
        assert_eq!(case.expected_terminal_state, "failed");
        assert_eq!(
            case.expected_error_code.as_deref(),
            Some("ai.provider.not_configured")
        );
        assert_eq!(case.forbidden_text, provider_forbidden_texts());
    });
    assert_case(&cases, "unauthorized_pet_selected", |case| {
        assert_eq!(case.expected_intent, "pet_care");
        assert_eq!(case.expected_gate_decision, "load_context");
        assert_eq!(case.expected_terminal_state, "completed");
        assert_eq!(
            case.expected_pet_resolution.as_deref(),
            Some("unauthorized_or_not_found")
        );
        assert_eq!(case.forbidden_text, forbidden_texts());
    });

    for case in &cases {
        assert_workbench_contract(case);
    }
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
        assert_eq!(
            decision.context_loaded, case.expected_context_loaded,
            "case {} context_loaded mismatch",
            case.name
        );
        assert_eq!(
            decision.enters_workbench(),
            case.expected_enters_workbench,
            "case {} workbench entry mismatch",
            case.name
        );
    }
}

fn parse_eval_cases() -> Vec<EvalCase> {
    serde_json::from_str(EVAL_CASES_JSON).expect("parse eval cases")
}

fn case_names(cases: &[EvalCase]) -> Vec<&str> {
    cases.iter().map(|case| case.name.as_str()).collect()
}

fn value_set<'a>(
    cases: &'a [EvalCase],
    value: impl Fn(&'a EvalCase) -> &'a str,
) -> BTreeSet<&'a str> {
    cases.iter().map(value).collect()
}

fn assert_case(cases: &[EvalCase], name: &str, check: impl FnOnce(&EvalCase)) {
    let case = cases
        .iter()
        .find(|case| case.name == name)
        .unwrap_or_else(|| panic!("missing eval case {name}"));
    check(case);
}

fn assert_workbench_contract(case: &EvalCase) {
    match case.expected_workbench.as_str() {
        "private_pet_context" => {
            assert!(
                case.expected_context_loaded,
                "case {} must load context",
                case.name
            );
            assert!(
                case.expected_enters_workbench,
                "case {} must enter workbench",
                case.name
            );
        }
        "light_response" => {
            assert!(
                !case.expected_context_loaded,
                "case {} must not load private context",
                case.name
            );
            assert!(
                case.expected_enters_workbench,
                "case {} must enter lightweight workbench",
                case.name
            );
        }
        "blocked" => {
            assert!(
                !case.expected_context_loaded,
                "case {} must not load context when blocked",
                case.name
            );
            assert!(
                !case.expected_enters_workbench,
                "case {} must not enter workbench when blocked",
                case.name
            );
        }
        workbench => panic!("case {} has unknown workbench {workbench}", case.name),
    }
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

fn intent_code(intent: AiIntent) -> &'static str {
    intent.code()
}

fn gate_decision_code(decision: &AiGateDecision) -> &'static str {
    decision.gate_code()
}
