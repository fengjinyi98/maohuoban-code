use axum::http::StatusCode;
use httpmock::MockServer;
use maohuoban_diagnostics::EventKind;
use serde_json::json;
use tower::ServiceExt;

#[path = "chat_stream_diagnostics/support.rs"]
mod support;

use super::{
    authorized_json_request, diagnostics_test_lock, json_request, login_and_get_token,
    response_json, response_text,
};
use support::{
    assert_diagnostics_field_present, assert_gate_decision_metadata_complete, create_pet,
    install_ai_test_diagnostics, install_runtime_tool_render_mocks,
    spawn_runtime_tool_render_test_app,
};

/// 流式聊天诊断事件允许开发期正文观测，但不能泄露认证敏感字段
#[tokio::test]
async fn ai_chat_stream_diagnostics_do_not_leak_sensitive_text() {
    let _guard = diagnostics_test_lock().lock_owned().await;
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    let diagnostics = install_ai_test_diagnostics();
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139019", "ios-ai-diagnostics").await;
    let pet = create_pet(&app, &access_token, "毛球").await;
    let pet_id = pet["id"].as_str().expect("pet id");

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "毛球今天拉肚子了怎么办",
                "surface": "home_private",
                "selected_pet_id": pet_id
            }),
        ))
        .await
        .expect("send diagnostics chat stream request");

    assert_eq!(response.status(), StatusCode::OK);
    let _ = response_text(response).await;
    diagnostics.flush().expect("flush diagnostics");

    let events = diagnostics.read_events().expect("diagnostics events");
    let forbidden_fields = [
        "contract-api-key",
        "api_key",
        "authorization",
        "Bearer",
        "Cookie",
    ];

    let ai_events: Vec<_> = events
        .iter()
        .filter(|event| event.message.starts_with("ai.chat."))
        .collect();
    assert!(!ai_events.is_empty(), "missing ai.chat diagnostics events");

    for event in &ai_events {
        let metadata = serde_json::to_string(&event.metadata).expect("serialize metadata");
        assert!(
            !forbidden_fields
                .iter()
                .any(|needle| { event.message.contains(needle) || metadata.contains(needle) }),
            "diagnostics leaked sensitive text in event: {event:?}"
        );
    }

    assert!(events.iter().any(|event| {
        event.kind == EventKind::Analytics
            && event.message == "ai.chat.stream.auth.succeeded"
            && event.metadata["actor_user_id_prefix"].is_string()
            && event.metadata["surface"] == json!("home_private")
    }));
    assert!(events.iter().any(|event| {
        event.kind == EventKind::Analytics
            && event.message == "ai.chat.stream.request.received"
            && event.metadata["surface"] == json!("home_private")
            && event.metadata["message_length_bucket"] == json!("1_32")
            && event.metadata["message"] == json!("毛球今天拉肚子了怎么办")
            && event.metadata["chat_session_id_prefix"].is_string()
            && event.metadata["message_id_prefix"].is_string()
    }));

    let finalizer_event = events
        .iter()
        .find(|event| event.message == "ai.chat.finalizer.completed")
        .expect("missing ai.chat.finalizer.completed diagnostics event");
    assert!(
        finalizer_event.metadata["terminal_status"]
            .as_str()
            .is_some_and(|status| !status.is_empty()),
        "finalizer diagnostics missing terminal_status"
    );
    assert!(
        finalizer_event.metadata["synchronous_writes"].is_array(),
        "finalizer diagnostics missing synchronous_writes"
    );
    assert!(
        finalizer_event.metadata["async_triggers"].is_array(),
        "finalizer diagnostics missing async_triggers"
    );
    assert!(
        finalizer_event.metadata["async_failures"].is_array(),
        "finalizer diagnostics missing async_failures"
    );
}

/// 流式聊天即使在 401 鉴权短路时也必须留下 ingress 和 auth.failed 观测点
#[tokio::test]
async fn ai_chat_stream_diagnostics_records_unauthorized_ingress_and_auth_failure() {
    let _guard = diagnostics_test_lock().lock_owned().await;
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    let diagnostics = install_ai_test_diagnostics();
    app.reset().await;

    let response = app
        .router()
        .clone()
        .oneshot(json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            json!({
                "message": "我的宠物多大了啊",
                "surface": "home_private"
            }),
        ))
        .await
        .expect("send unauthorized stream diagnostics request");

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
    let _ = response_json(response).await;
    diagnostics.flush().expect("flush diagnostics");

    let events = diagnostics.read_events().expect("diagnostics events");
    let ingress = events
        .iter()
        .find(|event| event.message == "ai.chat.stream.ingress.received")
        .expect("missing ai.chat.stream.ingress.received");
    assert_eq!(ingress.metadata["surface"], json!("home_private"));
    assert_eq!(ingress.metadata["message_length_bucket"], json!("1_32"));
    assert_eq!(ingress.metadata["has_selected_pet"], json!(false));

    let auth_failed = events
        .iter()
        .find(|event| event.message == "ai.chat.stream.auth.failed")
        .expect("missing ai.chat.stream.auth.failed");
    assert_eq!(auth_failed.metadata["surface"], json!("home_private"));
    assert_eq!(auth_failed.metadata["has_authorization"], json!(false));
    assert_eq!(auth_failed.metadata["bearer_prefix_present"], json!(false));
    assert_eq!(
        auth_failed.metadata["auth_error_code"],
        json!("access_invalid")
    );
    assert!(
        events
            .iter()
            .all(|event| event.message != "ai.chat.gate.decided"),
        "unauthorized stream request must not emit gate decision"
    );
}

/// 非流式聊天在 401 鉴权短路时也必须留下 ingress 和 auth.failed 观测点
#[tokio::test]
async fn ai_chat_non_stream_diagnostics_records_unauthorized_ingress_and_auth_failure() {
    let _guard = diagnostics_test_lock().lock_owned().await;
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    let diagnostics = install_ai_test_diagnostics();
    app.reset().await;

    let response = app
        .router()
        .clone()
        .oneshot(json_request(
            "POST",
            "/api/v1/ai/chat",
            json!({
                "message": "我的宠物多大了啊",
                "surface": "home_private"
            }),
        ))
        .await
        .expect("send unauthorized non-stream diagnostics request");

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
    let _ = response_json(response).await;
    diagnostics.flush().expect("flush diagnostics");

    let events = diagnostics.read_events().expect("diagnostics events");
    let ingress = events
        .iter()
        .find(|event| event.message == "ai.chat.non_stream.ingress.received")
        .expect("missing ai.chat.non_stream.ingress.received");
    assert_eq!(ingress.metadata["surface"], json!("home_private"));
    assert_eq!(ingress.metadata["message_length_bucket"], json!("1_32"));

    let auth_failed = events
        .iter()
        .find(|event| event.message == "ai.chat.non_stream.auth.failed")
        .expect("missing ai.chat.non_stream.auth.failed");
    assert_eq!(auth_failed.metadata["has_authorization"], json!(false));
    assert_eq!(auth_failed.metadata["bearer_prefix_present"], json!(false));
    assert_eq!(
        auth_failed.metadata["auth_error_code"],
        json!("access_invalid")
    );
    assert!(
        events
            .iter()
            .all(|event| event.message != "ai.chat.gate.decided"),
        "unauthorized non-stream request must not emit gate decision"
    );
}

/// 非流式聊天进入主链路时必须记录 auth、gate 和 provider 边界事件
#[tokio::test]
async fn ai_chat_non_stream_diagnostics_records_success_path_boundaries() {
    let _guard = diagnostics_test_lock().lock_owned().await;
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    let diagnostics = install_ai_test_diagnostics();
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139059", "ios-ai-non-stream-diag").await;
    let pet = create_pet(&app, &access_token, "毛球").await;
    let pet_id = pet["id"].as_str().expect("pet id");

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat",
            &access_token,
            json!({
                "message": "毛球今天怎么样",
                "surface": "home_private",
                "selected_pet_id": pet_id
            }),
        ))
        .await
        .expect("send non-stream diagnostics request");

    assert_eq!(response.status(), StatusCode::SERVICE_UNAVAILABLE);
    let _ = response_json(response).await;
    diagnostics.flush().expect("flush diagnostics");

    let events = diagnostics.read_events().expect("diagnostics events");
    assert!(events.iter().any(|event| {
        event.message == "ai.chat.non_stream.ingress.received"
            && event.metadata["surface"] == json!("home_private")
    }));
    assert!(events.iter().any(|event| {
        event.message == "ai.chat.non_stream.auth.succeeded"
            && event.metadata["actor_user_id_prefix"].is_string()
    }));
    assert!(events.iter().any(|event| {
        event.message == "ai.chat.gate.decided" && event.metadata["gate_decision"].is_string()
    }));
    assert!(events.iter().any(|event| {
        event.message == "ai.chat.provider.started" && event.metadata["engine_mode"].is_string()
    }));
}

/// 首页私域身份工具成功后必须记录 render plan 和 content blocks 观测
#[tokio::test]
async fn ai_chat_stream_diagnostics_records_render_plan_and_content_blocks() {
    let _guard = diagnostics_test_lock().lock_owned().await;
    let server = MockServer::start();
    let app = spawn_runtime_tool_render_test_app(&server).await;
    let diagnostics = install_ai_test_diagnostics();
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139069", "ios-ai-render-diag").await;
    let pet = create_pet(&app, &access_token, "梅录").await;
    let pet_id = pet["id"].as_str().expect("pet id");
    let (first_mock, second_mock) = install_runtime_tool_render_mocks(&server, pet_id);

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "我的宠物多大了",
                "surface": "home_private",
                "selected_pet_id": pet_id
            }),
        ))
        .await
        .expect("send render diagnostics chat stream request");

    assert_eq!(response.status(), StatusCode::OK);
    let _ = response_text(response).await;
    first_mock.assert();
    second_mock.assert();
    diagnostics.flush().expect("flush diagnostics");

    let events = diagnostics.read_events().expect("diagnostics events");
    assert!(events.iter().any(|event| {
        event.message == "ai.chat.render_plan.selected"
            && event.metadata["surface"] == json!("home_private")
            && event.metadata["allowed_block_kinds"]
                .as_array()
                .is_some_and(|kinds| kinds.iter().any(|kind| kind == "pet_profile_card"))
    }));
    assert!(events.iter().any(|event| {
        event.message == "ai.chat.content_blocks.emitted"
            && event.metadata["block_count"]
                .as_u64()
                .is_some_and(|count| count >= 2)
            && event.metadata["block_kinds"]
                .as_array()
                .is_some_and(|kinds| kinds.iter().any(|kind| kind == "pet_profile_card"))
    }));
}

/// 流式聊天诊断事件必须记录 gate 决策的四个必备字段
#[tokio::test]
async fn ai_chat_stream_diagnostics_records_gate_decision_fields() {
    let _guard = diagnostics_test_lock().lock_owned().await;
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    let diagnostics = install_ai_test_diagnostics();
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139029", "ios-ai-gate-diag").await;
    let pet = create_pet(&app, &access_token, "毛球").await;
    let pet_id = pet["id"].as_str().expect("pet id");

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "毛球今天吃什么好",
                "surface": "home_private",
                "selected_pet_id": pet_id
            }),
        ))
        .await
        .expect("send gate diagnostics chat stream request");

    assert_eq!(response.status(), StatusCode::OK);
    let _ = response_text(response).await;
    diagnostics.flush().expect("flush diagnostics");

    let events = diagnostics.read_events().expect("diagnostics events");
    let gate_event = events
        .iter()
        .find(|event| event.message == "ai.chat.gate.decided")
        .expect("missing ai.chat.gate.decided diagnostics event");

    assert_gate_decision_metadata_complete(&gate_event.metadata);
}

/// 流式聊天诊断事件必须记录 planning 决策字段
#[tokio::test]
async fn ai_chat_stream_diagnostics_records_planning_decision_fields() {
    let _guard = diagnostics_test_lock().lock_owned().await;
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    let diagnostics = install_ai_test_diagnostics();
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139049", "ios-ai-planning-diag").await;
    let pet = create_pet(&app, &access_token, "毛球").await;
    let pet_id = pet["id"].as_str().expect("pet id");

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "毛球今天拉肚子了怎么办",
                "surface": "home_private",
                "selected_pet_id": pet_id
            }),
        ))
        .await
        .expect("send planning diagnostics chat stream request");

    assert_eq!(response.status(), StatusCode::OK);
    let _ = response_text(response).await;
    diagnostics.flush().expect("flush diagnostics");

    let events = diagnostics.read_events().expect("diagnostics events");
    let planning_event = events
        .iter()
        .find(|event| event.message == "ai.chat.planning.decided")
        .expect("missing ai.chat.planning.decided diagnostics event");

    let required_fields = [
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
    ];
    for field in &required_fields {
        assert_diagnostics_field_present(&planning_event.metadata, field, "planning");
    }
    assert!(
        planning_event.metadata["step_list"]
            .as_array()
            .is_some_and(|steps| !steps.is_empty()),
        "planning diagnostics step_list must be a non-empty array"
    );
    assert!(
        planning_event.metadata["task_type"]
            .as_str()
            .is_some_and(|value| !value.is_empty()),
        "planning diagnostics task_type must be present"
    );
    assert!(
        planning_event.metadata["policy_decision"]
            .as_str()
            .is_some_and(|value| !value.is_empty()),
        "planning diagnostics policy_decision must be present"
    );
}

/// gate 诊断事件四个必备字段即使在不加载上下文的请求中也存在
#[tokio::test]
async fn ai_chat_stream_diagnostics_gate_fields_present_for_all_intents() {
    let _guard = diagnostics_test_lock().lock_owned().await;
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    let diagnostics = install_ai_test_diagnostics();
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139039", "ios-ai-gate-fields").await;

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "给我推荐一部好看的电影",
                "surface": "home_private"
            }),
        ))
        .await
        .expect("send gate fields diagnostics chat stream request");

    assert_eq!(response.status(), StatusCode::OK);
    let _ = response_text(response).await;
    diagnostics.flush().expect("flush diagnostics");

    let events = diagnostics.read_events().expect("diagnostics events");
    let gate_event = events
        .iter()
        .find(|event| event.message == "ai.chat.gate.decided")
        .expect("missing ai.chat.gate.decided diagnostics event");

    // 验证必备诊断字段始终存在
    let required_fields = [
        "intent",
        "gate_decision",
        "context_loaded",
        "risk_signal_present",
        "allow_processing",
    ];
    for field in &required_fields {
        assert_diagnostics_field_present(&gate_event.metadata, field, "gate");
    }
}
