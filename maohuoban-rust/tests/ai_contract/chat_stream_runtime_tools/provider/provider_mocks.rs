use httpmock::{Mock, MockServer, prelude::HttpMockRequest};
use std::time::Duration;

/// `install_runtime_tool_call_mocks` 安装 Runtime 工具调用模型响应
/// 核心职责：
/// - 固定首轮模型工具调用响应
/// - 固定工具回灌后的 followup 模型响应
pub fn install_runtime_tool_call_mocks<'a>(
    server: &'a MockServer,
    pet_id: &str,
) -> (Mock<'a>, Mock<'a>) {
    install_runtime_tool_call_mocks_with_followup_delay(server, pet_id, Duration::ZERO)
}

/// `install_runtime_tool_call_mocks_with_followup_delay` 安装带延迟的工具回灌 mock
/// 核心职责：
/// - 固定首轮工具调用响应
/// - 固定 followup 模型回答响应和延迟
pub fn install_runtime_tool_call_mocks_with_followup_delay<'a>(
    server: &'a MockServer,
    pet_id: &str,
    followup_delay: Duration,
) -> (Mock<'a>, Mock<'a>) {
    let first_body = runtime_tool_call_response_body(pet_id, "load_pet_identity_context");
    let first_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .matches(runtime_first_model_request)
            .body_contains("\"stream\":true")
            .body_contains("\"tools\"")
            .body_contains("load_pet_identity_context");
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(first_body);
    });
    let second_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .matches(runtime_followup_model_request)
            .body_contains("\"stream\":true")
            .body_contains("\"role\":\"tool\"")
            .body_contains("\"tool_call_id\":\"call_1\"");
        then.status(200)
            .delay(followup_delay)
            .header("content-type", "text/event-stream")
            .body(runtime_tool_followup_response_body());
    });
    (first_mock, second_mock)
}

/// `install_chained_runtime_tool_call_mocks` 安装链式 Runtime 工具调用响应
/// 核心职责：
/// - 固定首轮身份工具调用响应
/// - 固定第二轮饮食工具调用和最终回答响应
pub fn install_chained_runtime_tool_call_mocks<'a>(
    server: &'a MockServer,
    pet_id: &str,
) -> (Mock<'a>, Mock<'a>, Mock<'a>) {
    let first_body = runtime_tool_call_response_body(pet_id, "load_pet_identity_context");
    let second_body =
        runtime_tool_call_response_body_with_id(pet_id, "load_pet_current_diet_context", "call_2");
    let first_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .matches(runtime_first_model_request)
            .body_contains("\"stream\":true")
            .body_contains("\"tools\"")
            .body_contains("load_pet_identity_context");
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(first_body);
    });
    let second_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .matches(runtime_followup_model_request)
            .body_contains("\"stream\":true")
            .body_contains("\"tool_call_id\":\"call_1\"")
            .body_contains("load_pet_current_diet_context");
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(second_body);
    });
    let third_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .matches(runtime_second_followup_model_request)
            .body_contains("\"stream\":true")
            .body_contains("\"tool_call_id\":\"call_2\"");
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(runtime_tool_chain_followup_response_body());
    });
    (first_mock, second_mock, third_mock)
}

fn runtime_tool_call_response_body(pet_id: &str, tool_name: &str) -> String {
    runtime_tool_call_response_body_with_id(pet_id, tool_name, "call_1")
}

fn runtime_tool_call_response_body_with_id(
    pet_id: &str,
    tool_name: &str,
    tool_call_id: &str,
) -> String {
    let arguments = serde_json::json!({ "pet_id": pet_id }).to_string();
    format!(
        "data: {{\"choices\":[{{\"delta\":{{\"tool_calls\":[{{\"id\":{tool_call_id:?},\"function\":{{\"name\":{tool_name:?},\"arguments\":{arguments:?}}}}}]}}}}]}}\n\n\
         data: {{\"choices\":[{{\"finish_reason\":\"tool_calls\"}}],\"usage\":{{\"prompt_tokens\":8,\"completion_tokens\":2,\"total_tokens\":10}}}}\n\n\
         data: [DONE]\n\n"
    )
}

fn runtime_tool_followup_response_body() -> &'static str {
    "data: {\"choices\":[{\"delta\":{\"content\":\"已读取毛球档案，当前可以继续观察精神和食欲。\"}}]}\n\n\
     data: {\"choices\":[{\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":12,\"completion_tokens\":8,\"total_tokens\":20}}\n\n\
     data: [DONE]\n\n"
}

fn runtime_tool_chain_followup_response_body() -> &'static str {
    "data: {\"choices\":[{\"delta\":{\"content\":\"已读取毛球档案和当前饮食，当前可以继续观察精神和食欲。\"}}]}\n\n\
     data: {\"choices\":[{\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":14,\"completion_tokens\":10,\"total_tokens\":24}}\n\n\
     data: [DONE]\n\n"
}

fn runtime_first_model_request(req: &HttpMockRequest) -> bool {
    let body = request_body(req);
    body.contains("\"tools\"")
        && body.contains("load_pet_identity_context")
        && !body.contains("\"role\":\"tool\"")
}

/// `runtime_initial_model_request` 匹配确认提交前的初始模型请求
/// 核心职责：
/// - 区分初始用户请求和工具回灌请求
/// - 排除已经携带 tool_calls 的历史请求
pub fn runtime_initial_model_request(req: &HttpMockRequest) -> bool {
    let body = request_body(req);
    !body.contains("\"role\":\"tool\"") && !body.contains("\"tool_calls\"")
}

fn runtime_followup_model_request(req: &HttpMockRequest) -> bool {
    let body = request_body(req);
    body.contains("\"role\":\"tool\"") && body.contains("\"tool_call_id\":\"call_1\"")
}

fn runtime_second_followup_model_request(req: &HttpMockRequest) -> bool {
    let body = request_body(req);
    body.contains("\"role\":\"tool\"") && body.contains("\"tool_call_id\":\"call_2\"")
}

fn request_body(req: &HttpMockRequest) -> String {
    req.body
        .as_ref()
        .map(|body| String::from_utf8_lossy(body).into_owned())
        .unwrap_or_default()
}
