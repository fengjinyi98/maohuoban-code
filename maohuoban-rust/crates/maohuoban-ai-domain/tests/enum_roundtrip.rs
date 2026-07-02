// ai_domain_enum_roundtrip AI 领域枚举序列化 roundtrip 测试
// 核心职责：
// - 验证 AiIntent、AiConversationSurface、AiPetResolution、AiStreamEvent 等枚举 snake_case 序列化稳定
// - 验证未知值反序列化被拒绝

use maohuoban_ai_domain::ai::{
    AiAnswerVerification, AiBlockedReason, AiCitation, AiCitationSourceKind, AiConversationSurface,
    AiFactEntry, AiFactPackage, AiFactStrength, AiGateDecision, AiIntent, AiMessageRole,
    AiPetCandidate, AiPetDisplaySnapshot, AiPetResolution, AiProposedAction, AiProposedActionKind,
    AiProposedActionRisk, AiStreamEvent, AiToolCallStatus, AiVerificationStatus, LlmFinishReason,
    LlmRole, LlmStreamEvent, LlmToolCall, LlmUsage,
};
use uuid::Uuid;

#[test]
fn ai_intent_serializes_snake_case() {
    for (intent, expected) in [
        (AiIntent::Allowed, "\"allowed\""),
        (AiIntent::InvalidInput, "\"invalid_input\""),
    ] {
        let serialized = serde_json::to_string(&intent).expect("serialize intent");
        assert_eq!(serialized, expected);
        let deserialized: AiIntent = serde_json::from_str(&serialized).expect("deserialize intent");
        assert_eq!(deserialized, intent);
    }
}

#[test]
fn ai_intent_rejects_unknown_variant() {
    let result: Result<AiIntent, _> = serde_json::from_str("\"not_a_real_intent\"");
    assert!(result.is_err());
}

#[test]
fn ai_intent_pet_domain_classification() {
    assert!(!AiIntent::Allowed.is_pet_domain());
    assert!(!AiIntent::Allowed.requires_context_load());
}

#[test]
fn ai_gate_decision_allow_processing() {
    let blocked = AiGateDecision {
        intent: AiIntent::InvalidInput,
        context_loaded: false,
        risk_signal: Some("invalid_input".to_owned()),
        reason: "blocked".to_owned(),
    };
    assert!(!blocked.allow_processing());

    let allowed = AiGateDecision {
        intent: AiIntent::Allowed,
        context_loaded: false,
        risk_signal: None,
        reason: "ok".to_owned(),
    };
    assert!(allowed.allow_processing());
}

#[test]
fn ai_conversation_surface_snake_case() {
    assert_eq!(
        serde_json::to_string(&AiConversationSurface::HomePrivate).expect("serialize"),
        "\"home_private\""
    );
    assert_eq!(
        serde_json::to_string(&AiConversationSurface::UgcComment).expect("serialize"),
        "\"ugc_comment\""
    );
    assert!(AiConversationSurface::HomePrivate.is_private_surface());
}

#[test]
fn ai_pet_resolution_tagged_serialization() {
    let pet_id = Uuid::new_v4();
    let snapshot = AiPetDisplaySnapshot {
        pet_id,
        pet_name: "毛球".to_owned(),
        pet_avatar_url: None,
        pet_species: "cat".to_owned(),
        profile_number: "P001".to_owned(),
    };
    let resolved = AiPetResolution::Resolved {
        pet_id,
        snapshot: snapshot.clone(),
    };
    let serialized = serde_json::to_string(&resolved).expect("serialize resolution");
    assert!(serialized.contains("\"status\":\"resolved\""));
    let deserialized: AiPetResolution = serde_json::from_str(&serialized).expect("deserialize");
    assert_eq!(deserialized.resolved_pet_id(), Some(pet_id));
    assert!(deserialized.is_resolved());

    let needs_selection = AiPetResolution::NeedsSelection {
        candidates: vec![AiPetCandidate {
            pet_id,
            name: "毛球".to_owned(),
            avatar_url: None,
            species: "cat".to_owned(),
            profile_number: "P001".to_owned(),
        }],
    };
    let serialized = serde_json::to_string(&needs_selection).expect("serialize");
    assert!(serialized.contains("\"status\":\"needs_selection\""));

    let unauthorized = AiPetResolution::UnauthorizedOrNotFound;
    let serialized = serde_json::to_string(&unauthorized).expect("serialize");
    assert!(serialized.contains("\"status\":\"unauthorized_or_not_found\""));
    assert!(!unauthorized.is_resolved());

    let no_context = AiPetResolution::NoPetContext;
    assert_eq!(no_context.resolved_pet_id(), None);
}

#[test]
fn ai_pet_display_snapshot_from_candidate() {
    let candidate = AiPetCandidate {
        pet_id: Uuid::new_v4(),
        name: "豆豆".to_owned(),
        avatar_url: Some("https://example.com/a.png".to_owned()),
        species: "dog".to_owned(),
        profile_number: "P002".to_owned(),
    };
    let snapshot = AiPetDisplaySnapshot::from(&candidate);
    assert_eq!(snapshot.pet_name, "豆豆");
    assert_eq!(
        snapshot.pet_avatar_url.as_deref(),
        Some("https://example.com/a.png")
    );
}

#[test]
fn ai_stream_event_tagged_serialization() {
    let delta = AiStreamEvent::Delta {
        text: "你好".to_owned(),
    };
    let serialized = serde_json::to_string(&delta).expect("serialize delta");
    assert!(serialized.contains("\"event\":\"delta\""));
    assert_eq!(delta.event_name(), "delta");

    let started = AiStreamEvent::MessageStarted {
        chat_session_id: Uuid::new_v4(),
        message_id: Uuid::new_v4(),
        target_pet: None,
        title: "新对话".to_owned(),
    };
    assert_eq!(started.event_name(), "message_started");

    let error = AiStreamEvent::Error {
        code: "ai.provider_not_configured".to_owned(),
        message: "未配置".to_owned(),
        retryable: false,
        blocked_reason: None,
        safe_fallback_text: None,
    };
    let serialized = serde_json::to_string(&error).expect("serialize error");
    assert!(serialized.contains("\"event\":\"error\""));
    assert!(serialized.contains("\"retryable\":false"));
}

#[test]
fn ai_stream_event_citation_and_proposed_action() {
    let citation = AiCitation {
        source_kind: AiCitationSourceKind::DietAssignment,
        source_id: Uuid::new_v4(),
        label: "当前主粮".to_owned(),
    };
    let event = AiStreamEvent::Citation { citation };
    let serialized = serde_json::to_string(&event).expect("serialize");
    assert!(serialized.contains("\"event\":\"citation\""));
    assert!(serialized.contains("\"diet_assignment\""));

    let action = AiProposedAction {
        id: Uuid::new_v4(),
        action_kind: AiProposedActionKind::DietChangeConfirmation,
        target_pet_id: Uuid::new_v4(),
        payload: serde_json::json!({}),
        confirm_text: "确认换粮".to_owned(),
        risk_level: AiProposedActionRisk::Medium,
        source_message_id: None,
        confirmation_task_id: None,
    };
    assert!(action.requires_confirmation());
}

#[test]
fn llm_stream_event_tagged_serialization() {
    let delta = LlmStreamEvent::Delta {
        content: "hi".to_owned(),
    };
    let serialized = serde_json::to_string(&delta).expect("serialize");
    assert!(serialized.contains("\"kind\":\"delta\""));

    let finish = LlmStreamEvent::Finish {
        finish_reason: LlmFinishReason::Stop,
        usage: LlmUsage::default(),
    };
    let serialized = serde_json::to_string(&finish).expect("serialize");
    assert!(serialized.contains("\"kind\":\"finish\""));
}

#[test]
fn llm_role_and_tool_call_serialization() {
    assert_eq!(
        serde_json::to_string(&LlmRole::Assistant).expect("serialize"),
        "\"assistant\""
    );
    let tool_call = LlmToolCall {
        id: "call_1".to_owned(),
        name: "load_pet_identity_context".to_owned(),
        arguments: "{}".to_owned(),
    };
    let serialized = serde_json::to_string(&tool_call).expect("serialize");
    assert!(serialized.contains("\"load_pet_identity_context\""));
}

#[test]
fn ai_message_role_serialization() {
    assert_eq!(
        serde_json::to_string(&AiMessageRole::User).expect("serialize"),
        "\"user\""
    );
    assert_eq!(
        serde_json::to_string(&AiMessageRole::Assistant).expect("serialize"),
        "\"assistant\""
    );
}

#[test]
fn ai_answer_verification_blocked() {
    let verification =
        AiAnswerVerification::blocked(AiBlockedReason::WeakHintMisuse, "请确认后再提问".to_owned());
    assert!(verification.is_blocked());
    assert_eq!(
        verification.blocked_reason,
        Some(AiBlockedReason::WeakHintMisuse)
    );
    assert!(verification.safe_fallback_text.is_some());

    let passed = AiAnswerVerification::passed();
    assert!(!passed.is_blocked());
    assert_eq!(passed.status, AiVerificationStatus::Passed);
}

#[test]
fn ai_fact_package_strong_weak_separation() {
    let mut package = AiFactPackage::empty();
    package.facts.push(AiFactEntry {
        key: "current_staple".to_owned(),
        value: "渴望六种鱼".to_owned(),
        strength: AiFactStrength::Strong,
        citation_id: None,
    });
    package.weak_hints.push(AiFactEntry {
        key: "inventory_hint".to_owned(),
        value: "新增主粮".to_owned(),
        strength: AiFactStrength::Weak,
        citation_id: None,
    });

    let strong = package.strong_fact_values();
    assert_eq!(strong, vec!["渴望六种鱼"]);
    let weak = package.weak_hint_values();
    assert_eq!(weak, vec!["新增主粮"]);
}

#[test]
fn ai_tool_call_status_serialization() {
    assert_eq!(
        serde_json::to_string(&AiToolCallStatus::Allowed).expect("serialize"),
        "\"allowed\""
    );
    assert_eq!(
        serde_json::to_string(&AiToolCallStatus::Denied).expect("serialize"),
        "\"denied\""
    );
}

#[test]
fn ai_citation_source_kind_serialization() {
    assert_eq!(
        serde_json::to_string(&AiCitationSourceKind::PetEvent).expect("serialize"),
        "\"pet_event\""
    );
    assert_eq!(
        serde_json::to_string(&AiCitationSourceKind::AbnormalEpisode).expect("serialize"),
        "\"abnormal_episode\""
    );
}
