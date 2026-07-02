// diagnostics Provider 流式合同测试诊断断言
// 核心职责：
// - 安装隔离的文件型 diagnostics runtime
// - 验证 Provider、Workbench 和工具调用诊断字段
// - 检查诊断元数据不泄露认证密钥

use maohuoban_diagnostics::{
    CapturePolicy, CleanupPolicy, DiagnosticEvent, Diagnostics, DiagnosticsConfig,
    FileSegmentStore, PrivacyPolicy,
};
use serde_json::json;

pub(crate) fn install_provider_test_diagnostics() -> Diagnostics {
    let root = std::env::temp_dir().join(format!(
        "maohuoban-ai-provider-diagnostics-{}",
        uuid::Uuid::new_v4()
    ));
    let store = FileSegmentStore::new(root.join("segments"), 1024 * 1024).expect("store");
    Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_owned(),
        environment: "test".to_owned(),
        privacy: PrivacyPolicy::default(),
        capture: CapturePolicy::default(),
        cleanup: CleanupPolicy::default(),
        store: Box::new(store),
    })
    .expect("install diagnostics")
}

pub(crate) fn assert_provider_diagnostics(
    events: &[DiagnosticEvent],
    chat_session_id_prefix: &str,
    message_id_prefix: &str,
    expected_message: &str,
) {
    assert_required_provider_events(events, chat_session_id_prefix, message_id_prefix);
    assert_provider_request_prepared(
        events,
        chat_session_id_prefix,
        message_id_prefix,
        expected_message,
    );
    assert_workbench_built_event(events, chat_session_id_prefix, message_id_prefix);
    assert_provider_stream_payloads(events, chat_session_id_prefix, message_id_prefix);
    assert_provider_diagnostics_without_secrets(events);
}

fn assert_required_provider_events(
    events: &[DiagnosticEvent],
    chat_session_id_prefix: &str,
    message_id_prefix: &str,
) {
    for event_name in [
        "ai.provider.openai.request.prepared",
        "ai.provider.openai.http.response.started",
        "ai.provider.openai.stream.chunk",
        "ai.provider.openai.stream.event",
    ] {
        let event = events
            .iter()
            .find(|event| {
                event.message == event_name
                    && event.metadata["chat_session_id_prefix"] == json!(chat_session_id_prefix)
                    && event.metadata["message_id_prefix"] == json!(message_id_prefix)
            })
            .unwrap_or_else(|| panic!("missing provider diagnostics event {event_name}"));
        assert_eq!(
            event.metadata["chat_session_id_prefix"],
            json!(chat_session_id_prefix)
        );
        assert_eq!(
            event.metadata["message_id_prefix"],
            json!(message_id_prefix)
        );
        assert!(
            event.metadata["turn_id_prefix"]
                .as_str()
                .is_some_and(|value| !value.is_empty()),
            "missing turn correlation in {event:?}"
        );
        assert!(
            event.metadata["tool_call_id"].is_string(),
            "missing tool correlation field in {event:?}"
        );
        assert_eq!(event.metadata["provider"], json!("openai_compatible"));
        assert_eq!(event.metadata["model"], json!("contract-model"));
    }
}

fn assert_provider_request_prepared(
    events: &[DiagnosticEvent],
    chat_session_id_prefix: &str,
    message_id_prefix: &str,
    expected_message: &str,
) {
    assert!(events.iter().any(|event| {
        event.message == "ai.provider.openai.request.prepared"
            && event.metadata["chat_session_id_prefix"] == json!(chat_session_id_prefix)
            && event.metadata["message_id_prefix"] == json!(message_id_prefix)
            && event.metadata["provider"] == json!("openai_compatible")
            && event.metadata["model_route"] == json!("primary")
            && event.metadata["model"] == json!("contract-model")
            && event.metadata["request_body_text"]
                .as_str()
                .is_some_and(|body| {
                    body.contains(&format!("\"message\":\"{expected_message}\""))
                        || body.contains(expected_message)
                })
    }));
}

fn assert_workbench_built_event(
    events: &[DiagnosticEvent],
    chat_session_id_prefix: &str,
    message_id_prefix: &str,
) {
    assert!(events.iter().any(|event| {
        event.message == "ai.chat.workbench.built"
            && event.metadata["chat_session_id_prefix"] == json!(chat_session_id_prefix)
            && event.metadata["message_id_prefix"] == json!(message_id_prefix)
            && event.metadata["turn_id_prefix"]
                .as_str()
                .is_some_and(|value| !value.is_empty())
            && event.metadata["tool_call_id"].is_string()
            && event.metadata["provider"].is_string()
            && event.metadata["model"].is_string()
            && event.metadata["capability_catalog"]
                .as_array()
                .is_some_and(|capabilities| {
                    capabilities
                        .iter()
                        .any(|value| value == "private_pet_context")
                })
            && event.metadata["visible_tools"]
                .as_array()
                .is_some_and(|tools| {
                    tools
                        .iter()
                        .any(|value| value == "load_pet_identity_context")
                })
            && event.metadata["memory_count"] == json!(1)
            && event.metadata["recent_conversation_count"] == json!(0)
            && event.metadata["context_summary_present"] == json!(false)
    }));
}

fn assert_provider_stream_payloads(
    events: &[DiagnosticEvent],
    chat_session_id_prefix: &str,
    message_id_prefix: &str,
) {
    assert!(events.iter().any(|event| {
        event.message == "ai.provider.openai.stream.chunk"
            && event.metadata["chat_session_id_prefix"] == json!(chat_session_id_prefix)
            && event.metadata["message_id_prefix"] == json!(message_id_prefix)
            && event.metadata["chunk_text"]
                .as_str()
                .is_some_and(|body| body.contains("真实 Provider"))
    }));
    assert!(events.iter().any(|event| {
        event.message == "ai.provider.openai.stream.event"
            && event.metadata["chat_session_id_prefix"] == json!(chat_session_id_prefix)
            && event.metadata["message_id_prefix"] == json!(message_id_prefix)
            && event.metadata["event_name"] == json!("delta")
            && event.metadata["payload"]["content"] == json!("真实 Provider")
    }));
}

fn assert_provider_diagnostics_without_secrets(events: &[DiagnosticEvent]) {
    for event in events {
        let metadata = serde_json::to_string(&event.metadata).expect("serialize metadata");
        assert!(
            !metadata.contains("Bearer contract-api-key")
                && !metadata.contains("\"api_key\"")
                && !metadata.contains("contract-api-key")
                && !metadata.contains("Cookie"),
            "provider diagnostics leaked auth secret: {event:?}"
        );
    }
}
