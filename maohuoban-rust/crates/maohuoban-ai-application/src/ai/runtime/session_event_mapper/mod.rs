use maohuoban_ai_domain::ai::{
    AgentEvent, AgentToolStatus, AgentTurnStatus, LoopStep, LoopToolResult, LoopToolStatus,
    ModelCallOutcome,
};
use uuid::Uuid;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(super) enum StepFlow {
    Continue,
    Stop,
}

/// append_step_events 将 LoopStep 映射为 AgentEvent
/// 核心职责：
/// - 保持 Runtime 内部事件顺序稳定
/// - 返回当前 turn 是否需要停止推进
pub(super) fn append_step_events(
    turn_id: maohuoban_ai_domain::ai::AgentTurnId,
    step: LoopStep,
    engine_mode: &str,
    events: &mut Vec<AgentEvent>,
) -> StepFlow {
    match step {
        LoopStep::CallModel {
            model_label,
            tool_count,
            outcome,
        } => append_model_events(
            turn_id,
            model_label,
            tool_count,
            outcome,
            engine_mode,
            events,
        ),
        LoopStep::MessageDelta { text } => {
            events.push(AgentEvent::MessageDelta { turn_id, text });
            StepFlow::Continue
        }
        LoopStep::ClarifyUser {
            reason,
            suggested_actions,
        } => {
            events.push(AgentEvent::NeedsClarification {
                turn_id,
                reason,
                suggested_actions,
            });
            StepFlow::Stop
        }
        LoopStep::CallTools { tool_results } => append_tool_events(turn_id, tool_results, events),
        LoopStep::Done {
            message_id,
            final_text,
            status,
        } => append_done_event(turn_id, message_id, final_text, status, engine_mode, events),
    }
}

/// append_model_events 追加模型调用事件
/// 核心职责：
/// - 记录模型调用开始和完成事件
/// - 将 Provider 错误转换为 turn_failed 终态
fn append_model_events(
    turn_id: maohuoban_ai_domain::ai::AgentTurnId,
    model_label: maohuoban_ai_domain::ai::ModelLabel,
    tool_count: u32,
    outcome: ModelCallOutcome,
    engine_mode: &str,
    events: &mut Vec<AgentEvent>,
) -> StepFlow {
    events.push(AgentEvent::ModelCallStarted {
        turn_id,
        model_label,
        tool_count,
        engine_mode: engine_mode.to_owned(),
    });

    match outcome {
        ModelCallOutcome::Finished {
            finish_reason,
            usage,
            provider,
            model,
        } => {
            events.push(AgentEvent::ModelCallFinished {
                turn_id,
                finish_reason,
                usage,
                provider,
                model,
                engine_mode: engine_mode.to_owned(),
            });
            StepFlow::Continue
        }
        ModelCallOutcome::ProviderError {
            category,
            retryable,
            error_code,
        } => {
            events.push(AgentEvent::ProviderError {
                turn_id,
                category,
                retryable,
                engine_mode: engine_mode.to_owned(),
            });
            events.push(AgentEvent::TurnFailed {
                turn_id,
                error_code,
                retryable,
                engine_mode: engine_mode.to_owned(),
            });
            StepFlow::Stop
        }
    }
}

/// append_tool_events 追加工具调用事件
/// 核心职责：
/// - 记录工具开始和执行结果
/// - 遇到确认需求时停止当前 turn 推进
fn append_tool_events(
    turn_id: maohuoban_ai_domain::ai::AgentTurnId,
    tool_results: Vec<LoopToolResult>,
    events: &mut Vec<AgentEvent>,
) -> StepFlow {
    let mut flow = StepFlow::Continue;

    for tool_result in tool_results {
        match tool_result.status {
            LoopToolStatus::Requested => events.push(AgentEvent::ToolStarted {
                turn_id,
                tool_call_id: tool_result.tool_call.id,
                tool_name: tool_result.tool_call.name,
            }),
            LoopToolStatus::Succeeded => append_tool_finished(
                turn_id,
                tool_result.tool_call.id,
                AgentToolStatus::Succeeded,
                tool_result.citation_count,
                events,
            ),
            LoopToolStatus::Denied => append_tool_finished(
                turn_id,
                tool_result.tool_call.id,
                AgentToolStatus::Denied,
                tool_result.citation_count,
                events,
            ),
            LoopToolStatus::Failed => append_tool_finished(
                turn_id,
                tool_result.tool_call.id,
                AgentToolStatus::Failed,
                tool_result.citation_count,
                events,
            ),
            LoopToolStatus::RequiresConfirmation => {
                append_tool_finished(
                    turn_id,
                    tool_result.tool_call.id,
                    AgentToolStatus::Succeeded,
                    tool_result.citation_count,
                    events,
                );
                if let Some(confirmation) = tool_result.confirmation {
                    events.push(AgentEvent::NeedsConfirmation {
                        turn_id,
                        confirmation_task_id: Uuid::parse_str(&confirmation.confirmation_task_id)
                            .unwrap_or_else(|_| Uuid::new_v4()),
                        question_text: confirmation.question_text,
                    });
                    flow = StepFlow::Stop;
                }
            }
        }
    }

    flow
}

/// append_tool_finished 追加工具完成事件
/// 核心职责：
/// - 统一工具完成事件字段
fn append_tool_finished(
    turn_id: maohuoban_ai_domain::ai::AgentTurnId,
    tool_call_id: String,
    status: AgentToolStatus,
    citation_count: u32,
    events: &mut Vec<AgentEvent>,
) {
    events.push(AgentEvent::ToolFinished {
        turn_id,
        tool_call_id,
        status,
        citation_count,
    });
}

/// append_done_event 追加 turn 终态事件
/// 核心职责：
/// - 将 Done step 映射为完成或失败事件
/// - 结束当前 turn 推进
fn append_done_event(
    turn_id: maohuoban_ai_domain::ai::AgentTurnId,
    message_id: Uuid,
    final_text: String,
    status: AgentTurnStatus,
    engine_mode: &str,
    events: &mut Vec<AgentEvent>,
) -> StepFlow {
    if status == AgentTurnStatus::Failed {
        events.push(AgentEvent::TurnFailed {
            turn_id,
            error_code: "ai.runtime_failed".to_owned(),
            retryable: false,
            engine_mode: engine_mode.to_owned(),
        });
    } else {
        events.push(AgentEvent::TurnFinished {
            turn_id,
            message_id,
            final_text,
            status,
        });
    }

    StepFlow::Stop
}
