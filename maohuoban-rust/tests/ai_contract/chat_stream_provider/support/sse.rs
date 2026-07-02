// sse Agent 流式合同测试 SSE 断言
// 核心职责：
// - 从 SSE 文本中提取指定事件数据
// - 提供 Agent Runtime 流式输出基础断言

use serde_json::Value;

pub(crate) fn sse_event_data(text: &str, event_name: &str) -> Value {
    let mut lines = text.lines();
    while let Some(line) = lines.next() {
        if line.trim() == format!("event: {event_name}") {
            for data_line in lines.by_ref() {
                if let Some(data) = data_line.strip_prefix("data: ") {
                    return serde_json::from_str(data).expect("parse sse data");
                }
            }
        }
    }

    panic!("missing SSE event {event_name}, got: {text}");
}

pub(crate) fn uuid_prefix_from_sse(event: &Value, field: &str) -> String {
    event[field]
        .as_str()
        .expect("uuid field")
        .chars()
        .take(8)
        .collect()
}

pub(crate) fn assert_agent_stream_response(text: &str) {
    assert!(
        text.contains("event: answer_delta"),
        "SSE should contain answer_delta event, got: {text}"
    );
    assert!(
        text.contains("真实 Provider"),
        "SSE should contain configured provider content, got: {text}"
    );
    assert!(
        text.contains("event: answer_completed"),
        "SSE should contain completion event, got: {text}"
    );
}
