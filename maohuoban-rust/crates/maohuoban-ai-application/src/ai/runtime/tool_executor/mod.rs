use std::sync::Arc;

use maohuoban_ai_domain::ai::{LlmToolCall, LoopToolResult};
use serde_json::Value;

use crate::ai::guardrail::{GuardrailDecision, ToolCallGuardrail, ToolCallRecord};
use crate::ai::tools::{AiToolContext, ToolRegistry};

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
                let gateway_result = registry
                    .record_guardrail_hard_stop(
                        &tool_context,
                        &tool_call,
                        &safe_user_message,
                        &internal_reason,
                    )
                    .await;
                let result = gateway_result.loop_result;
                guardrail.record(ToolCallRecord {
                    tool_call: tool_call.clone(),
                    status: result.status,
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
                let gateway_result = registry.execute_tool_call(&tool_context, &tool_call).await;
                let mut loop_result = gateway_result.loop_result;
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
                let gateway_result = registry.execute_tool_call(&tool_context, &tool_call).await;
                let loop_result = gateway_result.loop_result;
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
