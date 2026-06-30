use std::sync::Arc;

use maohuoban_ai_domain::ai::{
    LlmToolCall, LoopToolResult, LoopToolStatus, PROVIDER_USER_VISIBLE_FAILURE_MESSAGE,
    ToolFactProjector,
};
use serde_json::Value;

use crate::ai::guardrail::{GuardrailDecision, ToolCallGuardrail, ToolCallRecord};
use crate::ai::tools::{AiToolContext, AiToolResult, ToolRegistry};

pub(crate) async fn execute_tool_calls(
    registry: Arc<ToolRegistry>,
    tool_context: AiToolContext,
    tool_calls: Vec<LlmToolCall>,
    guardrail: &mut ToolCallGuardrail,
) -> (Vec<LoopToolResult>, Option<GuardrailDecision>) {
    let mut results = Vec::with_capacity(tool_calls.len());

    for tool_call in tool_calls {
        let risk_level = registry
            .get(&tool_call.name)
            .map(|tool| tool.metadata().risk_level);

        let decision = guardrail.evaluate(&tool_call, risk_level);

        match decision {
            GuardrailDecision::HardStop {
                safe_user_message,
                internal_reason,
            } => {
                let failure = maohuoban_ai_domain::ai::ToolFailure::new(
                    "guardrail.hard_stop",
                    false,
                    &safe_user_message,
                    &internal_reason,
                );
                let result = LoopToolResult::failed_with_failure(tool_call.clone(), failure);
                guardrail.record(ToolCallRecord {
                    tool_call: tool_call.clone(),
                    status: LoopToolStatus::Failed,
                    produced_facts: false,
                    risk_level,
                });
                results.push(result);
                return (
                    results,
                    Some(GuardrailDecision::HardStop {
                        safe_user_message,
                        internal_reason,
                    }),
                );
            }
            GuardrailDecision::SoftReminder { message } => {
                let args = serde_json::from_str::<Value>(&tool_call.arguments)
                    .unwrap_or_else(|_| Value::Object(serde_json::Map::new()));
                let result = registry.call(&tool_call.name, &tool_context, &args).await;
                let mut loop_result = to_loop_tool_result(tool_call.clone(), result);
                let produced_facts = output_has_facts(loop_result.output.as_deref());
                loop_result.guardrail_message = Some(message);
                guardrail.record(ToolCallRecord {
                    tool_call: tool_call.clone(),
                    status: loop_result.status,
                    produced_facts,
                    risk_level,
                });
                results.push(loop_result);
            }
            GuardrailDecision::Allow => {
                let args = serde_json::from_str::<Value>(&tool_call.arguments)
                    .unwrap_or_else(|_| Value::Object(serde_json::Map::new()));
                let result = registry.call(&tool_call.name, &tool_context, &args).await;
                let loop_result = to_loop_tool_result(tool_call.clone(), result);
                let produced_facts = output_has_facts(loop_result.output.as_deref());
                guardrail.record(ToolCallRecord {
                    tool_call: tool_call.clone(),
                    status: loop_result.status,
                    produced_facts,
                    risk_level,
                });
                results.push(loop_result);
            }
        }
    }

    (results, None)
}

fn output_has_facts(output: Option<&str>) -> bool {
    let Some(json_str) = output else {
        return false;
    };
    let Ok(parsed) = serde_json::from_str::<Value>(json_str) else {
        return false;
    };
    parsed
        .get("facts")
        .and_then(Value::as_array)
        .is_some_and(|facts| !facts.is_empty())
}

fn to_loop_tool_result(tool_call: LlmToolCall, result: AiToolResult) -> LoopToolResult {
    if result.allowed {
        let mut projected = ToolFactProjector::project_facts(&result.facts);
        projected.reference_ids.extend(result.returned_ref_ids);
        let json =
            serde_json::to_string(&projected).unwrap_or_else(|_| "{\"facts\":[]}".to_owned());
        return LoopToolResult::succeeded(tool_call, json);
    }

    if let Some(confirmation) = result.confirmation {
        return LoopToolResult::requires_confirmation(tool_call, confirmation);
    }

    if let Some(failure) = result.failure {
        return LoopToolResult::failed_with_failure(tool_call, failure);
    }

    if let Some(reason) = result.denied_reason {
        return LoopToolResult::denied(tool_call, reason);
    }

    if let Some(reason) = result.failed_reason {
        return LoopToolResult::failed(tool_call, reason);
    }

    LoopToolResult::failed(tool_call, PROVIDER_USER_VISIBLE_FAILURE_MESSAGE.to_owned())
}
