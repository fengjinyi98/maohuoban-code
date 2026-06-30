use maohuoban_ai_domain::ai::{
    LlmMessage, LlmRole, LoopToolResult, LoopToolStatus, ToolFactProjector,
};
use serde_json::Value;

pub(crate) fn tool_result_to_message(tool_result: &LoopToolResult) -> LlmMessage {
    let content = match tool_result.status {
        LoopToolStatus::Succeeded => {
            let base = tool_result
                .output
                .clone()
                .unwrap_or_else(|| "{}".to_owned());
            if let Some(msg) = &tool_result.guardrail_message {
                merge_guardrail_message(&base, msg)
            } else {
                base
            }
        }
        LoopToolStatus::Denied => {
            let projected = ToolFactProjector::project_denied(
                tool_result.denied_reason.as_deref().unwrap_or_default(),
            );
            serde_json::to_string(&projected).unwrap_or_else(|_| "{}".to_owned())
        }
        LoopToolStatus::Failed => {
            if let Some(failure) = &tool_result.failure {
                serde_json::json!({
                    "status": "failed",
                    "error_code": failure.error_code,
                    "recoverable": failure.recoverable,
                    "message": failure.safe_user_message,
                })
                .to_string()
            } else {
                let projected = ToolFactProjector::project_failed(
                    tool_result.failed_reason.as_deref().unwrap_or_default(),
                );
                serde_json::to_string(&projected).unwrap_or_else(|_| "{}".to_owned())
            }
        }
        LoopToolStatus::RequiresConfirmation => serde_json::json!({
            "status": "requires_confirmation",
            "confirmation": tool_result.confirmation,
        })
        .to_string(),
        LoopToolStatus::Requested => "{}".to_owned(),
    };

    LlmMessage {
        role: LlmRole::Tool,
        content,
        reasoning_content: None,
        tool_call_id: Some(tool_result.tool_call.id.clone()),
        tool_calls: Vec::new(),
    }
}

pub(crate) fn prefetched_tool_context_message(tool_results: &[LoopToolResult]) -> LlmMessage {
    let payload: Vec<serde_json::Value> = tool_results
        .iter()
        .map(|result| {
            serde_json::json!({
                "tool": result.tool_call.name,
                "status": format!("{:?}", result.status),
                "content": result.output.as_deref().unwrap_or("{}"),
            })
        })
        .collect();
    LlmMessage {
        role: LlmRole::System,
        content: serde_json::json!({
            "prefetched_tool_context": payload,
            "instruction": "这些是系统在回答前预取的可信宠物上下文，只用于回答当前用户问题。",
        })
        .to_string(),
        reasoning_content: None,
        tool_call_id: None,
        tool_calls: Vec::new(),
    }
}

pub(crate) fn non_empty_string(value: String) -> Option<String> {
    if value.trim().is_empty() {
        None
    } else {
        Some(value)
    }
}

fn merge_guardrail_message(base_output: &str, message: &str) -> String {
    match serde_json::from_str::<Value>(base_output) {
        Ok(mut json) => {
            if let Some(obj) = json.as_object_mut() {
                obj.insert(
                    "_guardrail_reminder".to_owned(),
                    Value::String(message.to_owned()),
                );
            }
            serde_json::to_string(&json).unwrap_or_else(|_| base_output.to_owned())
        }
        Err(_) => serde_json::json!({
            "output": base_output,
            "_guardrail_reminder": message,
        })
        .to_string(),
    }
}
