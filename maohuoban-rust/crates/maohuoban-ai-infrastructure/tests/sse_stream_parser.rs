// sse_stream_parser SSE chunk 解析测试
// 核心职责：
// - 验证 OpenAI 兼容 SSE chunk 被正确解析为 LlmStreamEvent
// - 支持 delta、finish、usage、[DONE] 处理
// - 遵循 TDD：先写失败测试（red），再实现解析器（green）

use maohuoban_ai_domain::ai::{LlmFinishReason, LlmStreamEvent};
use maohuoban_ai_infrastructure::provider::parse_sse_stream;
use maohuoban_ai_infrastructure::provider::sse::parse_sse_buffer;

#[test]
fn parse_delta_sequence_in_order() {
    let sse = "\
data: {\"choices\":[{\"delta\":{\"content\":\"你好\"}}]}\n\
\n\
data: {\"choices\":[{\"delta\":{\"content\":\"，毛球\"}}]}\n\
\n\
data: {\"choices\":[{\"delta\":{\"content\":\"怎么样\"}}]}\n\
\n\
data: {\"choices\":[{\"delta\":{\"content\":\"了\"}}]}\n\
\n\
data: [DONE]\n\
\n";

    let events = parse_sse_stream(sse);
    let deltas: Vec<String> = events
        .iter()
        .filter_map(|e| match e {
            Ok(LlmStreamEvent::Delta { content }) => Some(content.clone()),
            _ => None,
        })
        .collect();

    assert_eq!(deltas, vec!["你好", "，毛球", "怎么样", "了"]);
    assert_eq!(events.len(), 4); // 4 deltas, [DONE] 不产生事件
}

#[test]
fn parse_finish_event_with_usage() {
    let sse = "\
data: {\"choices\":[{\"delta\":{\"content\":\"ok\"}}]}\n\
\n\
data: {\"choices\":[{\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":10,\"completion_tokens\":5,\"total_tokens\":15}}\n\
\n\
data: [DONE]\n\
\n";

    let events = parse_sse_stream(sse);
    let finish = events
        .iter()
        .find_map(|e| match e {
            Ok(LlmStreamEvent::Finish {
                finish_reason,
                usage,
            }) => Some((*finish_reason, *usage)),
            _ => None,
        })
        .expect("should have finish event");

    assert_eq!(finish.0, LlmFinishReason::Stop);
    assert_eq!(finish.1.total_tokens, 15);
    assert_eq!(finish.1.input_tokens, 10);
    assert_eq!(finish.1.output_tokens, 5);
}

#[test]
fn parse_done_marker_produces_no_event() {
    let sse = "data: [DONE]\n\n";
    let events = parse_sse_stream(sse);
    assert!(events.is_empty());
}

#[test]
fn parse_tool_call_delta() {
    let sse = "\
data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"id\":\"call_1\",\"function\":{\"name\":\"load_pet_identity_context\",\"arguments\":\"\"}}]}}]}\n\
\n\
data: [DONE]\n\
\n";

    let events = parse_sse_stream(sse);
    let tool_call = events
        .iter()
        .find_map(|e| match e {
            Ok(LlmStreamEvent::ToolCall { tool_call }) => Some(tool_call.clone()),
            _ => None,
        })
        .expect("should have tool call event");

    assert_eq!(tool_call.id, "call_1");
    assert_eq!(tool_call.name, "load_pet_identity_context");
}

#[test]
fn parse_tool_call_delta_fragments_into_single_complete_call() {
    let sse = "\
data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"index\":0,\"id\":\"call_1\",\"type\":\"function\",\"function\":{\"name\":\"load_pet_identity_context\",\"arguments\":\"\"}}]}}]}\n\
\n\
data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"index\":0,\"function\":{\"arguments\":\"{\\\"pet_id\\\":\\\"11111111-1111-1111-1111-111111111111\"}}]}}]}\n\
\n\
data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"index\":0,\"function\":{\"arguments\":\"\\\"}\"}}]}}]}\n\
\n\
data: {\"choices\":[{\"delta\":{},\"finish_reason\":\"tool_calls\"}],\"usage\":{\"prompt_tokens\":12,\"completion_tokens\":5,\"total_tokens\":17}}\n\
\n\
data: [DONE]\n\
\n";

    let events = parse_sse_stream(sse);
    let tool_calls: Vec<_> = events
        .iter()
        .filter_map(|event| match event {
            Ok(LlmStreamEvent::ToolCall { tool_call }) => Some(tool_call.clone()),
            _ => None,
        })
        .collect();

    assert_eq!(tool_calls.len(), 1);
    assert_eq!(tool_calls[0].id, "call_1");
    assert_eq!(tool_calls[0].name, "load_pet_identity_context");
    assert_eq!(
        tool_calls[0].arguments,
        "{\"pet_id\":\"11111111-1111-1111-1111-111111111111\"}"
    );
}

#[test]
fn parse_error_in_stream() {
    let sse = "\
data: {\"error\":{\"message\":\"rate limited\"}}\n\
\n";

    let events = parse_sse_stream(sse);
    assert!(events.len() == 1);
    assert!(events[0].is_err());
}

#[test]
fn parse_incomplete_buffer_returns_no_events() {
    // 不完整的 SSE 数据（没有空行结尾）
    let sse = "data: {\"choices\":[{\"delta\":{\"content\":\"partial\"}}]}";
    let events = parse_sse_stream(sse);
    assert!(events.is_empty());
}

#[test]
fn parse_buffer_preserves_partial_json_line_across_chunks() {
    let (events, remaining) = parse_sse_buffer("data: {\"choices\":[{\"delta\":{\"content\":\"par");
    assert!(events.is_empty());
    assert!(
        !remaining.ends_with('\n'),
        "partial line must not be turned into a complete SSE line"
    );

    let completed = format!("{remaining}{}", "tial\"}}]}\n\n");
    let (events, remaining) = parse_sse_buffer(&completed);
    assert!(remaining.is_empty());

    let deltas: Vec<&str> = events
        .iter()
        .filter_map(|event| match event {
            Ok(LlmStreamEvent::Delta { content }) => Some(content.as_str()),
            _ => None,
        })
        .collect();
    assert_eq!(deltas, vec!["partial"]);
}

#[test]
fn parse_multiple_finish_reasons() {
    let sse = "\
data: {\"choices\":[{\"finish_reason\":\"length\"}],\"usage\":{\"prompt_tokens\":1,\"completion_tokens\":1,\"total_tokens\":2}}\n\
\n\
data: [DONE]\n\
\n";

    let events = parse_sse_stream(sse);
    let finish = events
        .iter()
        .find_map(|e| match e {
            Ok(LlmStreamEvent::Finish { finish_reason, .. }) => Some(*finish_reason),
            _ => None,
        })
        .expect("should have finish event");

    assert_eq!(finish, LlmFinishReason::Length);
}
