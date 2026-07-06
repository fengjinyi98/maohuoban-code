use maohuoban_ai_domain::ai::{
    AgentEvent, AgentToolStatus, AgentTurnStatus, AgentTurnTerminationReason,
    AiConfirmationTaskAction, AiConfirmationTaskActionKind, AiConfirmationTaskPreview, LoopStep,
    LoopToolResult, LoopToolStatus, ModelCallOutcome,
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
            StepFlow::Continue
        }
        LoopStep::CallTools { tool_results } => append_tool_events(turn_id, tool_results, events),
        LoopStep::Done {
            message_id,
            final_text,
            status,
            termination_reason,
            error_code,
        } => append_done_event(
            DoneEventInput {
                turn_id,
                message_id,
                final_text,
                status,
                termination_reason,
                error_code,
            },
            engine_mode,
            events,
        ),
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
                termination_reason: None,
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
                tool_result.fact_package,
                events,
            ),
            LoopToolStatus::Denied => append_tool_finished(
                turn_id,
                tool_result.tool_call.id,
                AgentToolStatus::Denied,
                tool_result.citation_count,
                None,
                events,
            ),
            LoopToolStatus::Failed => append_tool_finished(
                turn_id,
                tool_result.tool_call.id,
                AgentToolStatus::Failed,
                tool_result.citation_count,
                None,
                events,
            ),
            LoopToolStatus::RequiresConfirmation => {
                let tool_name = tool_result.tool_call.name.clone();
                append_tool_finished(
                    turn_id,
                    tool_result.tool_call.id,
                    AgentToolStatus::Succeeded,
                    tool_result.citation_count,
                    tool_result.fact_package,
                    events,
                );
                if let Some(confirmation) = tool_result.confirmation {
                    events.push(AgentEvent::NeedsConfirmation {
                        turn_id,
                        confirmation_task_id: Uuid::parse_str(&confirmation.confirmation_task_id)
                            .unwrap_or_else(|_| Uuid::new_v4()),
                        question_text: confirmation.question_text,
                        preview: confirmation_task_preview(&tool_name, &confirmation.args),
                        actions: confirmation_task_actions(),
                    });
                    flow = StepFlow::Stop;
                }
            }
        }
    }

    flow
}

/// confirmation_task_preview 构建确认任务展示预览
/// 核心职责：
/// - 从已创建的工具确认需求投影用户可见候选内容
/// - 保持确认卡展示与后续 commit 使用同一个确认任务来源
fn confirmation_task_preview(
    tool_name: &str,
    args: &serde_json::Value,
) -> AiConfirmationTaskPreview {
    let note = args
        .get("note")
        .and_then(serde_json::Value::as_str)
        .unwrap_or("待确认记录")
        .trim()
        .to_owned();
    let (title, event_subkind) = match tool_name {
        "prepare_pet_observation_write" => ("准备记录一条观察", "agent_observation_note"),
        "prepare_pet_abnormal_symptom_creation" => ("准备创建异常追踪", "abnormal_symptom"),
        _ => ("准备执行一项确认", "agent_confirmation"),
    };

    AiConfirmationTaskPreview {
        title: title.to_owned(),
        event_subkind: event_subkind.to_owned(),
        note,
        source_label: "毛球更新".to_owned(),
    }
}

/// confirmation_task_actions 构建确认任务动作集合
/// 核心职责：
/// - 固定确认卡显式授权动作
/// - 让前端避免用自然语言文本表达写入授权
fn confirmation_task_actions() -> Vec<AiConfirmationTaskAction> {
    vec![
        AiConfirmationTaskAction {
            kind: AiConfirmationTaskActionKind::Approve,
            label: "确认写入".to_owned(),
        },
        AiConfirmationTaskAction {
            kind: AiConfirmationTaskActionKind::Reject,
            label: "取消".to_owned(),
        },
    ]
}

/// append_tool_finished 追加工具完成事件
/// 核心职责：
/// - 统一工具完成事件字段
fn append_tool_finished(
    turn_id: maohuoban_ai_domain::ai::AgentTurnId,
    tool_call_id: String,
    status: AgentToolStatus,
    citation_count: u32,
    fact_package: Option<Box<maohuoban_ai_domain::ai::AiFactPackage>>,
    events: &mut Vec<AgentEvent>,
) {
    events.push(AgentEvent::ToolFinished {
        turn_id,
        tool_call_id,
        status,
        citation_count,
        fact_package,
    });
}

/// DoneEventInput Turn 终态事件输入
/// 核心职责：
/// - 聚合 Done step 的事件字段
/// - 保持事件追加函数参数稳定
struct DoneEventInput {
    turn_id: maohuoban_ai_domain::ai::AgentTurnId,
    message_id: Uuid,
    final_text: String,
    status: AgentTurnStatus,
    termination_reason: AgentTurnTerminationReason,
    error_code: Option<String>,
}

/// append_done_event 追加 turn 终态事件
/// 核心职责：
/// - 将 Done step 映射为完成或失败事件
/// - 结束当前 turn 推进
fn append_done_event(
    input: DoneEventInput,
    engine_mode: &str,
    events: &mut Vec<AgentEvent>,
) -> StepFlow {
    if input.status == AgentTurnStatus::Failed {
        events.push(AgentEvent::TurnFailed {
            turn_id: input.turn_id,
            error_code: input
                .error_code
                .unwrap_or_else(|| "ai.runtime_failed".to_owned()),
            retryable: false,
            engine_mode: engine_mode.to_owned(),
            termination_reason: Some(input.termination_reason),
        });
    } else {
        events.push(AgentEvent::TurnFinished {
            turn_id: input.turn_id,
            message_id: input.message_id,
            final_text: input.final_text,
            status: input.status,
            termination_reason: Some(input.termination_reason),
        });
    }

    StepFlow::Stop
}
