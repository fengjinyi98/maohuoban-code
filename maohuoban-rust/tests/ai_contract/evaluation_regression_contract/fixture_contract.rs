use std::collections::{BTreeMap, BTreeSet, HashSet};

use maohuoban_ai_application::ai::skill::{SkillBundle, SkillDiagnosticsSnapshot};
use maohuoban_ai_domain::ai::AgentTurnId;
use uuid::Uuid;

use super::{
    REQUIRED_DIAGNOSTICS_FAMILIES, parse_diagnostics_assertions, parse_eval_cases,
    parse_replay_case,
};

#[test]
fn eval_fixture_freezes_workbench_context_and_terminal_expectations() {
    let cases = parse_eval_cases();
    assert_eq!(cases.len(), 11);

    let names = cases
        .iter()
        .map(|case| case.name.as_str())
        .collect::<Vec<_>>();
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

    let workbench_kinds = cases
        .iter()
        .map(|case| case.expected_workbench.as_str())
        .collect::<BTreeSet<_>>();
    assert_eq!(workbench_kinds, BTreeSet::from(["blocked", "runtime"]));

    let terminal_states = cases
        .iter()
        .map(|case| case.expected_terminal_state.as_str())
        .collect::<BTreeSet<_>>();
    assert_eq!(
        terminal_states,
        BTreeSet::from(["blocked", "completed", "failed"])
    );

    assert!(
        cases.iter().any(|case| !case.expected_context_loaded),
        "fixture must contain context-free cases"
    );
    assert!(
        cases.iter().any(|case| case.expected_enters_workbench),
        "fixture must contain workbench-entering cases"
    );
    assert!(
        cases.iter().any(|case| !case.expected_enters_workbench),
        "fixture must contain hard-blocked cases"
    );

    for case in &cases {
        assert_eq!(case.surface, "home_private");
        assert!(
            !case.message.is_empty(),
            "case {} missing message",
            case.name
        );
        assert!(
            !case.expected_intent.is_empty(),
            "case {} missing intent",
            case.name
        );
        assert!(
            !case.expected_gate_decision.is_empty(),
            "case {} missing gate decision",
            case.name
        );
        assert!(
            !case.forbidden_text.is_empty(),
            "case {} missing forbidden text",
            case.name
        );
    }

    assert!(
        cases
            .iter()
            .any(|case| case.expected_error_code.as_deref() == Some("ai.provider.not_configured")),
        "fixture must contain provider failure case"
    );
    assert!(
        cases.iter().any(|case| {
            case.expected_pet_resolution.as_deref() == Some("unauthorized_or_not_found")
        }),
        "fixture must contain unauthorized pet case"
    );
}

#[test]
fn replay_and_diagnostics_fixtures_freeze_failure_and_assertion_families() {
    let replay = parse_replay_case();
    assert_eq!(replay.schema_version, 1);
    assert_eq!(replay.name, "provider_failure_turn");
    assert_eq!(replay.case_type, "failure");
    assert_eq!(replay.session_surface, "home_private");
    assert_eq!(replay.expected_terminal_state, "failed");
    assert!(!replay.description.is_empty());
    assert_eq!(
        replay.event_sequence,
        vec![
            "turn_started",
            "model_call_started",
            "provider_error",
            "turn_failed"
        ]
    );
    assert!(replay.expected_replay_read.by_turn);
    assert!(replay.expected_replay_read.preserve_order);
    assert_eq!(
        replay.expected_replay_read.projector_terminal_event,
        "error"
    );

    let diagnostics = parse_diagnostics_assertions();
    assert_eq!(diagnostics.schema_version, 1);
    assert_eq!(diagnostics.name, "ai_chat_diagnostics");
    let families = diagnostics
        .assertion_families
        .iter()
        .map(|family| family.family.as_str())
        .collect::<Vec<_>>();
    assert_eq!(families, REQUIRED_DIAGNOSTICS_FAMILIES);
    for family in &diagnostics.assertion_families {
        assert!(
            !family.event.is_empty(),
            "family {} missing event",
            family.family
        );
        assert!(
            !family.required_fields.is_empty(),
            "family {} missing required fields",
            family.family
        );
    }
    for forbidden in [
        "contract-api-key",
        "api_key",
        "authorization",
        "Bearer",
        "Cookie",
    ] {
        assert!(
            diagnostics
                .forbidden_text
                .iter()
                .any(|candidate| candidate == forbidden),
            "diagnostics forbidden text missing {forbidden}"
        );
    }
}

#[test]
fn diagnostics_fixture_matches_runtime_protocol_events_and_fields() {
    let diagnostics = parse_diagnostics_assertions();
    let expected_contract = expected_diagnostics_contract();

    for family in &diagnostics.assertion_families {
        let expected = expected_contract
            .get(family.family.as_str())
            .unwrap_or_else(|| panic!("unexpected diagnostics family {}", family.family));
        assert_eq!(
            family.event, expected.event,
            "diagnostics family {} event drifted",
            family.family
        );
        assert_eq!(
            family
                .required_fields
                .iter()
                .cloned()
                .collect::<BTreeSet<_>>(),
            expected
                .required_fields
                .iter()
                .map(|field| (*field).to_owned())
                .collect::<BTreeSet<_>>(),
            "diagnostics family {} required fields drifted",
            family.family
        );
    }
}

#[test]
fn diagnostics_assertion_families_do_not_duplicate_or_drop_required_fields() {
    let diagnostics = parse_diagnostics_assertions();
    let mut families = HashSet::new();

    for family in diagnostics.assertion_families {
        assert!(
            families.insert(family.family.clone()),
            "duplicated diagnostics family {}",
            family.family
        );
        let required_fields = family.required_fields.iter().collect::<HashSet<_>>();
        assert_eq!(
            required_fields.len(),
            family.required_fields.len(),
            "diagnostics family {} has duplicated fields",
            family.family
        );
    }
}

// ExpectedDiagnosticsFamily diagnostics fixture 的真实协议期望
// 核心职责：
// - 固定 fixture family 对应的真实事件名
// - 固定每个 family 必须守住的 metadata 字段集合
struct ExpectedDiagnosticsFamily {
    event: &'static str,
    required_fields: Vec<&'static str>,
}

fn expected_diagnostics_contract() -> BTreeMap<&'static str, ExpectedDiagnosticsFamily> {
    BTreeMap::from([
        expected_family(
            "request",
            "ai.chat.stream.request.received",
            &[
                "surface",
                "message_length_bucket",
                "message",
                "chat_session_id_prefix",
                "message_id_prefix",
            ],
        ),
        expected_family(
            "response",
            "ai.chat.finalizer.completed",
            &[
                "terminal_status",
                "synchronous_writes",
                "async_triggers",
                "async_failures",
            ],
        ),
        expected_family(
            "tool",
            "ai.chat.tool_gateway.completed",
            &[
                "session_id",
                "turn_id",
                "message_id",
                "tool_name",
                "policy_decision",
                "duration_ms",
                "failure_code",
            ],
        ),
        expected_family(
            "event",
            "ai.chat.session.event.appended",
            &["session_id", "turn_id", "event_name"],
        ),
        expected_family(
            "finalizer",
            "ai.chat.finalizer.completed",
            &[
                "terminal_status",
                "synchronous_writes",
                "async_triggers",
                "async_failures",
            ],
        ),
        expected_family(
            "planning",
            "ai.chat.planning.decided",
            &[
                "session_id",
                "turn_id",
                "message_id",
                "task_type",
                "step_list",
                "current_step",
                "step_transition",
                "replan_reason",
                "terminal_step",
                "policy_decision",
            ],
        ),
        ("skill", expected_skill_diagnostics_contract()),
        expected_family(
            "provider",
            "ai.provider.openai.request.prepared",
            &[
                "provider",
                "model",
                "model_route",
                "request_body_text",
                "chat_session_id_prefix",
                "message_id_prefix",
                "turn_id_prefix",
                "tool_call_id",
            ],
        ),
        expected_family("redaction", "*", &["forbidden_text"]),
    ])
}

fn expected_family(
    family: &'static str,
    event: &'static str,
    required_fields: &[&'static str],
) -> (&'static str, ExpectedDiagnosticsFamily) {
    (
        family,
        ExpectedDiagnosticsFamily {
            event,
            required_fields: required_fields.to_vec(),
        },
    )
}

fn expected_skill_diagnostics_contract() -> ExpectedDiagnosticsFamily {
    let metadata_fields = SkillDiagnosticsSnapshot::new(
        Uuid::nil(),
        AgentTurnId::from_uuid(Uuid::nil()),
        Uuid::nil(),
        &SkillBundle::from_active_skills(Vec::new()),
    )
    .to_metadata_entries()
    .into_iter()
    .map(|(field, _)| field)
    .collect();

    ExpectedDiagnosticsFamily {
        event: SkillDiagnosticsSnapshot::event_name(),
        required_fields: metadata_fields,
    }
}
