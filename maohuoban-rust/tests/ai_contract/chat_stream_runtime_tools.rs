// chat_stream_runtime_tools Runtime 工具链路流式合同测试
// 核心职责：
// - 验证模型工具调用经 Tool Gateway 执行后回灌到二次模型
// - 验证工具进度在二次模型完成前通过 SSE 到达

use axum::http::StatusCode;
use futures_util::StreamExt;
use httpmock::MockServer;
use maohuoban_ai_application::ai::tools::ToolRegistry;
use maohuoban_ai_domain::ai::LlmToolCall;
use maohuoban_pet_application::pet::AgentConfirmationTaskRepository;
use maohuoban_pet_domain::pet::{
    AgentConfirmationTask, ConfirmationTaskKind, ConfirmationTaskStatus,
};
use maohuoban_pet_infrastructure::postgres::PostgresAgentConfirmationTaskRepository;
use serde_json::json;
use std::sync::{Arc, Mutex};
use std::time::Duration;
use tower::ServiceExt;
use uuid::Uuid;

#[path = "chat_stream_runtime_tools/gateway.rs"]
mod gateway;
#[path = "chat_stream_runtime_tools/support.rs"]
mod support;

use super::{authorized_json_request, diagnostics_test_lock, login_and_get_token, response_text};
use gateway::{
    ConfirmationContractTool, FailedContractTool, assert_recorded_audit,
    test_gateway_context_with_audits,
};
use support::{
    assert_runtime_tool_diagnostics, assert_runtime_tool_stream_contract, create_pet,
    install_chained_runtime_tool_call_mocks, install_runtime_tool_call_mocks,
    install_runtime_tool_call_mocks_with_followup_delay, install_runtime_tool_test_diagnostics,
    read_sse_until_contains, runtime_initial_model_request, spawn_runtime_tool_test_app,
    sse_event_data_all,
};

/// Provider 返回工具调用时 `/api/v1/ai/chat/stream` 通过自有 Agent Runtime 执行工具并回灌
#[tokio::test]
async fn ai_chat_stream_executes_runtime_tool_call_and_followup_model() {
    let _guard = diagnostics_test_lock().lock_owned().await;
    let server = MockServer::start();
    let app = spawn_runtime_tool_test_app(&server).await;
    let diagnostics = install_runtime_tool_test_diagnostics();
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139021", "ios-ai-runtime-tool").await;
    let pet = create_pet(&app, &access_token, "毛球").await;
    let pet_id = pet["id"].as_str().expect("pet id");
    let (first_mock, second_mock) = install_runtime_tool_call_mocks(&server, pet_id);

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "读取毛球档案后告诉我状态",
                "surface": "home_private",
                "selected_pet_id": pet_id
            }),
        ))
        .await
        .expect("send runtime tool chat stream request");

    assert_eq!(response.status(), StatusCode::OK);
    let text = response_text(response).await;

    first_mock.assert();
    second_mock.assert();
    assert_runtime_tool_stream_contract(&text);
    diagnostics.flush().expect("flush diagnostics");
    let events = diagnostics.read_events().expect("diagnostics events");
    assert_runtime_tool_diagnostics(&events);
}

/// 用户拒绝确认任务时，后端关闭任务且不写入宠物事件
#[tokio::test]
async fn ai_chat_confirmation_task_reject_dismisses_without_pet_event() {
    let server = MockServer::start();
    let app = spawn_runtime_tool_test_app(&server).await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139025", "ios-ai-runtime-reject").await;
    let pet = create_pet(&app, &access_token, "毛球").await;
    let pet_id = Uuid::parse_str(pet["id"].as_str().expect("pet id")).expect("pet uuid");
    let repo = PostgresAgentConfirmationTaskRepository::new(app.pool().clone());
    let confirmation_task_id = Uuid::new_v4();

    repo.create(AgentConfirmationTask {
        id: confirmation_task_id,
        pet_id,
        task_kind: ConfirmationTaskKind::SymptomFollowup,
        question_text: "是否确认写入这条观察记录？".to_owned(),
        candidate_payload: Some(json!({
            "event_kind": "health",
            "event_subkind": "symptom_followup",
            "note": "精神好转，食欲仍减少"
        })),
        source_hint_id: None,
        source_ref_type: None,
        source_ref_id: None,
        status: ConfirmationTaskStatus::Pending,
        answer_payload: None,
        resolved_event_id: None,
        created_at: chrono::DateTime::from_timestamp_nanos(0),
        resolved_at: None,
    })
    .await
    .expect("create confirmation task");

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            &format!("/api/v1/ai/confirmation-tasks/{confirmation_task_id}/reject"),
            &access_token,
            json!({}),
        ))
        .await
        .expect("reject confirmation task");

    assert_eq!(response.status(), StatusCode::OK);
    let updated = repo
        .get_by_id(confirmation_task_id)
        .await
        .expect("load rejected task");
    assert_eq!(updated.status, ConfirmationTaskStatus::Dismissed);
    assert_eq!(updated.resolved_event_id, None);
    assert_eq!(updated.answer_payload, Some(json!({"decision": "reject"})));

    let event_count: i64 = sqlx::query_scalar(
        r"SELECT COUNT(*) FROM pet_events WHERE pet_id = $1::uuid AND event_subkind IN ('agent_observation_note', 'symptom_followup')",
    )
    .bind(pet_id)
    .fetch_one(app.pool())
    .await
    .expect("count pet events");
    assert_eq!(event_count, 0);
}

/// 用户确认写入是授权命令，不应作为聊天消息再次进入模型
#[tokio::test]
async fn ai_chat_confirmation_task_approve_commits_without_user_message() {
    let server = MockServer::start();
    let app = spawn_runtime_tool_test_app(&server).await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139026", "ios-ai-runtime-approve").await;
    let pet = create_pet(&app, &access_token, "毛球").await;
    let pet_id = Uuid::parse_str(pet["id"].as_str().expect("pet id")).expect("pet uuid");
    let repo = PostgresAgentConfirmationTaskRepository::new(app.pool().clone());
    let confirmation_task_id = Uuid::new_v4();

    repo.create(AgentConfirmationTask {
        id: confirmation_task_id,
        pet_id,
        task_kind: ConfirmationTaskKind::SymptomFollowup,
        question_text: "是否确认写入这条观察记录？".to_owned(),
        candidate_payload: Some(json!({
            "event_kind": "health",
            "event_subkind": "agent_observation_note",
            "note": "精神状态转好，食欲比平时少但仍有进食",
            "source": "agent_runtime_confirmed_write"
        })),
        source_hint_id: None,
        source_ref_type: None,
        source_ref_id: None,
        status: ConfirmationTaskStatus::Pending,
        answer_payload: None,
        resolved_event_id: None,
        created_at: chrono::DateTime::from_timestamp_nanos(0),
        resolved_at: None,
    })
    .await
    .expect("create confirmation task");

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            &format!("/api/v1/ai/confirmation-tasks/{confirmation_task_id}/approve"),
            &access_token,
            json!({}),
        ))
        .await
        .expect("approve confirmation task");

    assert_eq!(response.status(), StatusCode::OK);
    let updated = repo
        .get_by_id(confirmation_task_id)
        .await
        .expect("load approved task");
    assert_eq!(updated.status, ConfirmationTaskStatus::Answered);
    assert!(updated.resolved_event_id.is_some());

    let event_count: i64 = sqlx::query_scalar(
        r"SELECT COUNT(*) FROM pet_events WHERE pet_id = $1::uuid AND event_subkind = 'agent_observation_note'",
    )
    .bind(pet_id)
    .fetch_one(app.pool())
    .await
    .expect("count pet events");
    assert_eq!(event_count, 1);

    let confirmation_message_count: i64 = sqlx::query_scalar(
        r"SELECT COUNT(*) FROM ai_messages WHERE role = 'user' AND content LIKE '%确认写入%'",
    )
    .fetch_one(app.pool())
    .await
    .expect("count confirmation user messages");
    assert_eq!(confirmation_message_count, 0);
}

/// Runtime 工具链支持 followup 再发第二次工具调用后再完成回答
#[tokio::test]
async fn ai_chat_stream_supports_chained_runtime_tool_calls() {
    let _guard = diagnostics_test_lock().lock_owned().await;
    let server = MockServer::start();
    let app = spawn_runtime_tool_test_app(&server).await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139023", "ios-ai-runtime-tool-chain").await;
    let pet = create_pet(&app, &access_token, "毛球").await;
    let pet_id = pet["id"].as_str().expect("pet id");
    let (first_mock, second_mock, third_mock) =
        install_chained_runtime_tool_call_mocks(&server, pet_id);

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "先读取毛球档案，再读取当前饮食后告诉我状态",
                "surface": "home_private",
                "selected_pet_id": pet_id
            }),
        ))
        .await
        .expect("send chained runtime tool chat stream request");

    assert_eq!(response.status(), StatusCode::OK);
    let text = response_text(response).await;

    first_mock.assert();
    second_mock.assert();
    third_mock.assert();
    assert!(
        text.contains("已读取毛球档案和当前饮食，当前可以继续观察精神和食欲。"),
        "SSE should complete after chained runtime tool calls, got: {text}"
    );
}

/// Runtime 工具链可创建观察记录确认任务，并在确认后提交真实写入
#[tokio::test]
#[allow(clippy::too_many_lines)]
async fn ai_chat_stream_prepare_and_commit_observation_write() {
    let _guard = diagnostics_test_lock().lock_owned().await;
    let server = MockServer::start();
    let app = spawn_runtime_tool_test_app(&server).await;
    let diagnostics = install_runtime_tool_test_diagnostics();
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139024", "ios-ai-runtime-write").await;
    let pet = create_pet(&app, &access_token, "毛球").await;
    let pet_id = pet["id"].as_str().expect("pet id");

    let prepare_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .body_contains("\"stream\":true")
            .body_contains("prepare_pet_observation_write")
            .body_contains("帮我记录今天拉稀");
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(
                "data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"id\":\"call_prepare\",\"function\":{\"name\":\"prepare_pet_observation_write\",\"arguments\":\"{\\\"note\\\":\\\"今天拉稀\\\"}\"}}]}}]}\n\n\
                 data: {\"choices\":[{\"finish_reason\":\"tool_calls\"}],\"usage\":{\"prompt_tokens\":8,\"completion_tokens\":2,\"total_tokens\":10}}\n\n\
                 data: [DONE]\n\n",
            );
    });

    let prepare_response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "帮我记录今天拉稀",
                "surface": "home_private",
                "selected_pet_id": pet_id
            }),
        ))
        .await
        .expect("send prepare observation stream request");

    assert_eq!(prepare_response.status(), StatusCode::OK);
    let prepare_text = response_text(prepare_response).await;
    assert!(
        prepare_mock.hits() >= 1,
        "prepare request should hit upstream at least once"
    );
    let confirmation_event = sse_event_data_all(&prepare_text, "confirmation_task")
        .into_iter()
        .next()
        .expect("confirmation task event");
    let confirmation_task_id = confirmation_event["confirmation_task_id"]
        .as_str()
        .expect("confirmation task id")
        .to_owned();
    assert_eq!(
        confirmation_event["preview"]["title"].as_str(),
        Some("准备记录一条观察")
    );
    assert_eq!(
        confirmation_event["preview"]["event_subkind"].as_str(),
        Some("agent_observation_note")
    );
    assert_eq!(
        confirmation_event["preview"]["note"].as_str(),
        Some("今天拉稀")
    );
    assert_eq!(
        confirmation_event["preview"]["source_label"].as_str(),
        Some("毛球更新")
    );
    assert_eq!(
        confirmation_event["actions"][0]["kind"].as_str(),
        Some("approve")
    );
    assert_eq!(
        confirmation_event["actions"][1]["kind"].as_str(),
        Some("reject")
    );

    let confirmation_count: i64 =
        sqlx::query_scalar(r"SELECT COUNT(*) FROM agent_confirmation_tasks WHERE id = $1::uuid")
            .bind(Uuid::parse_str(&confirmation_task_id).expect("parse confirmation task id"))
            .fetch_one(app.pool())
            .await
            .expect("count confirmation task");
    assert_eq!(confirmation_count, 1);

    let commit_tool_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .matches(runtime_initial_model_request)
            .body_contains("\"stream\":true")
            .body_contains("当前待确认任务")
            .body_contains("commit_pet_observation_write")
            .body_contains(&confirmation_task_id);
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(
                "data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"id\":\"call_commit\",\"function\":{\"name\":\"commit_pet_observation_write\",\"arguments\":\"{\\\"confirmation_task_id\\\":\\\""
                    .to_owned()
                    + &confirmation_task_id
                    + "\\\"}\"}}]}}]}\n\n\
                 data: {\"choices\":[{\"finish_reason\":\"tool_calls\"}],\"usage\":{\"prompt_tokens\":8,\"completion_tokens\":2,\"total_tokens\":10}}\n\n\
                 data: [DONE]\n\n",
            );
    });

    let commit_answer_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .body_contains("\"stream\":true")
            .body_contains("\"tool_call_id\":\"call_commit\"");
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(
                "data: {\"choices\":[{\"delta\":{\"content\":\"已为毛球写入观察记录。\"}}]}\n\n\
                 data: {\"choices\":[{\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":12,\"completion_tokens\":8,\"total_tokens\":20}}\n\n\
                 data: [DONE]\n\n",
            );
    });

    let commit_response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "确认写入这条观察记录",
                "surface": "home_private",
                "selected_pet_id": pet_id,
                "confirmation_task_id": confirmation_task_id
            }),
        ))
        .await
        .expect("send commit observation stream request");

    assert_eq!(commit_response.status(), StatusCode::OK);
    let commit_text = response_text(commit_response).await;
    diagnostics.flush().expect("flush diagnostics");
    let events = diagnostics.read_events().expect("diagnostics events");
    let runtime_requests: Vec<String> = events
        .iter()
        .filter(|event| event.message == "ai.runtime.model.request.prepared")
        .filter_map(|event| serde_json::to_string(&event.metadata).ok())
        .collect();
    assert!(
        commit_tool_mock.hits() >= 1,
        "commit tool request should hit upstream at least once; runtime requests: {runtime_requests:?}"
    );
    assert!(
        commit_answer_mock.hits() >= 1,
        "commit answer followup request should hit upstream at least once; runtime requests: {runtime_requests:?}"
    );
    assert!(commit_text.contains("已为毛球写入观察记录。"));

    let answered_count: i64 = sqlx::query_scalar(
        r"SELECT COUNT(*) FROM agent_confirmation_tasks WHERE id = $1::uuid AND status = 'answered'"
    )
    .bind(Uuid::parse_str(&confirmation_task_id).expect("parse confirmation task id"))
    .fetch_one(app.pool())
    .await
    .expect("count answered confirmation task");
    assert_eq!(answered_count, 1);

    let event_count: i64 = sqlx::query_scalar(
        r"SELECT COUNT(*) FROM pet_events WHERE pet_id = $1::uuid AND event_subkind = 'agent_observation_note'"
    )
    .bind(Uuid::parse_str(pet_id).expect("parse pet id"))
    .fetch_one(app.pool())
    .await
    .expect("count observation event");
    assert_eq!(event_count, 1);
}

/// Runtime 工具进度在二次模型完成前通过 SSE 到达
#[tokio::test]
async fn ai_chat_stream_emits_runtime_tool_progress_before_followup_model_finishes() {
    let server = MockServer::start();
    let app = spawn_runtime_tool_test_app(&server).await;
    app.reset().await;
    let access_token =
        login_and_get_token(&app, "13800139022", "ios-ai-runtime-tool-progress").await;
    let pet = create_pet(&app, &access_token, "毛球").await;
    let pet_id = pet["id"].as_str().expect("pet id");
    let (first_mock, second_mock) = install_runtime_tool_call_mocks_with_followup_delay(
        &server,
        pet_id,
        Duration::from_secs(3),
    );

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "读取毛球档案后告诉我状态",
                "surface": "home_private",
                "selected_pet_id": pet_id
            }),
        ))
        .await
        .expect("send runtime tool progress chat stream request");

    assert_eq!(response.status(), StatusCode::OK);
    let mut body_stream = response.into_body().into_data_stream();
    let partial_text = read_sse_until_contains(
        &mut body_stream,
        &["event: execution_trace_completed"],
        Duration::from_secs(2),
    )
    .await;

    let completed_events = sse_event_data_all(&partial_text, "execution_trace_completed");
    assert!(
        completed_events.iter().any(|event| {
            event["display_text"]
                .as_str()
                .is_some_and(|text| text.contains("宠物档案") || text.contains("档案权限"))
                && event["status"] == "completed"
        }),
        "SSE should stream execution trace before followup model finishes, got: {completed_events:?}"
    );
    assert!(
        !partial_text.contains("已读取毛球档案，当前可以继续观察精神和食欲。"),
        "SSE should stream tool progress before followup model answer, got: {partial_text}"
    );
    let mut full_text = partial_text;
    while let Some(chunk) = body_stream.next().await {
        let chunk = chunk.expect("read remaining SSE chunk");
        full_text.push_str(&String::from_utf8_lossy(&chunk));
    }
    first_mock.assert();
    second_mock.assert();
    let completed_events = sse_event_data_all(&full_text, "execution_trace_completed");
    assert!(
        completed_events.iter().any(|event| {
            event["display_text"]
                .as_str()
                .is_some_and(|text| text.contains("宠物档案") || text.contains("档案权限"))
                && event["status"] == "completed"
        }),
        "SSE should stream backend-provided execution trace completion text, got: {completed_events:?}"
    );
    assert!(
        full_text.contains("已读取毛球档案，当前可以继续观察精神和食欲。"),
        "SSE should still complete with followup model answer, got: {full_text}"
    );
}

/// Tool Gateway 合同记录未知工具拒绝态
#[tokio::test]
async fn ai_contract_tool_gateway_records_denied_diagnostics() {
    let audits = Arc::new(Mutex::new(Vec::new()));
    let registry = ToolRegistry::new();
    let ctx = test_gateway_context_with_audits(audits.clone());

    let result = registry
        .execute_tool_call(
            &ctx,
            &LlmToolCall {
                id: "call_denied".to_owned(),
                name: "missing_runtime_tool".to_owned(),
                arguments: "{}".to_owned(),
            },
        )
        .await
        .audit;

    assert_eq!(result.tool_name, "missing_runtime_tool");
    assert_eq!(result.policy_decision, "denied");
    assert!(result.failure_code.is_none());
    assert_eq!(result.risk_level, "low");
    assert_eq!(result.toolset, "unknown");
    assert!(result.session_id.is_some());
    assert!(result.turn_id.is_some());
    assert!(result.message_id.is_some());
    assert_recorded_audit(&audits, "missing_runtime_tool", "denied", None);
}

/// Tool Gateway 合同记录工具执行失败态
#[tokio::test]
async fn ai_contract_tool_gateway_records_failed_diagnostics() {
    let audits = Arc::new(Mutex::new(Vec::new()));
    let mut registry = ToolRegistry::new();
    registry.register(FailedContractTool);
    let ctx = test_gateway_context_with_audits(audits.clone());

    let result = registry
        .execute_tool_call(
            &ctx,
            &LlmToolCall {
                id: "call_failed".to_owned(),
                name: "load_pet_current_diet_context".to_owned(),
                arguments: "{}".to_owned(),
            },
        )
        .await
        .audit;

    assert_eq!(result.tool_name, "load_pet_current_diet_context");
    assert_eq!(result.policy_decision, "failed");
    assert_eq!(
        result.failure_code.as_deref(),
        Some("ai.provider_not_configured")
    );
    assert_eq!(result.risk_level, "low");
    assert_eq!(result.toolset, "private_pet_context");
    assert!(result.session_id.is_some());
    assert!(result.turn_id.is_some());
    assert!(result.message_id.is_some());
    assert_recorded_audit(
        &audits,
        "load_pet_current_diet_context",
        "failed",
        Some("ai.provider_not_configured"),
    );
}

/// Tool Gateway diagnostics 记录确认需求态
#[tokio::test]
async fn ai_contract_tool_gateway_records_requires_confirmation_diagnostics() {
    let audits = Arc::new(Mutex::new(Vec::new()));
    let mut registry = ToolRegistry::new();
    registry.register(ConfirmationContractTool);
    let ctx = test_gateway_context_with_audits(audits.clone());

    let result = registry
        .execute_tool_call(
            &ctx,
            &LlmToolCall {
                id: "call_requires_confirmation".to_owned(),
                name: "create_pet_reminder".to_owned(),
                arguments: json!({ "title": "吃药" }).to_string(),
            },
        )
        .await;

    assert_eq!(result.audit.policy_decision, "requires_confirmation");
    assert!(result.audit.failure_code.is_none());
    assert_eq!(result.audit.risk_level, "high");
    assert_eq!(result.audit.toolset, "confirmation");
    assert_recorded_audit(
        &audits,
        "create_pet_reminder",
        "requires_confirmation",
        None,
    );
}
